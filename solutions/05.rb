require 'digest/sha1'

class ObjectStore
  def self.init(&block)
      self.new(&block)
  end

  def initialize(&block)
    @repo_branch_group = BranchGroup.new
    @current_branch = @repo_branch_group.current_branch

    if block_given?
      instance_eval &block
    end
  end

  def branch
    @repo_branch_group
  end

  def add(name, object)
    to_be_committed[name] = object
    ReturnObject.new(true, "Added #{name} to stage.", object)
  end

  def commit(message)
    if to_be_committed != last_committed_objects
      new_commit = Commit.new(message, to_be_committed)
      count = (last_committed_objects.size - to_be_committed.size).abs

      commits_list.insert(0, new_commit)
      @current_branch.head = new_commit
      return_message = "#{message}\n\t#{count} objects changed"
      ReturnObject.new(true, return_message, new_commit)
    else
      ReturnObject.new(false, "Nothing to commit, working directory clean.")
    end
  end

  def remove(name)
    if last_committed_objects.has_key?(name)
      removed_object = to_be_committed.delete(name)
      ReturnObject.new(true, "Added #{name} for removal.", removed_object)
    else
      ReturnObject.new(false, "Object #{name} is not committed.")
    end
  end

  def checkout(commit_hash)
    found_commit = commits_list.find { |commit| commit.hash == commit_hash }
    if found_commit.nil?
      ReturnObject.new(false, "Commit #{commit_hash} does not exist.")
    else
      @current_branch.head = found_commit
      commits_list.drop_while { |commit| commit != found_commit }
      message = "HEAD is now at #{commit_hash}."
      ReturnObject.new(true, message, @current_branch.head)
    end
  end

  def log
    if commits_list.size == 0
      message = "Branch #{current_branch_name} does not have any commits yet."
      ReturnObject.new(false, message)
    else
      log_message = String.new
      commits_list.each { |commit| log_message << commit.log_message }
      ReturnObject.new(true, log_message.chomp!.chomp!)
    end
  end

  def head
    if commits_list.size == 0
      message = "Branch #{current_branch_name} does not have any commits yet."
      ReturnObject.new(false, message)
    else
      message = @current_branch.head.message
      ReturnObject.new(true, message, @current_branch.head)
    end
  end

  def get(name)
    if last_committed_objects.has_key?(name)
      found_object = last_committed_objects[name]
      ReturnObject.new(true, "Found object #{name}.", found_object)
    else
      ReturnObject.new(false, "Object #{name} is not committed.")
    end
  end

  private

  def last_committed_objects
    head.result.nil? ? {} : head.result.objects_hash
  end

  def to_be_committed
    @current_branch.to_be_committed
  end

  def commits_list
    @current_branch.commits_list
  end

  def branch_list
     @repo_branch_group.branch_list
  end

  def current_branch_name
    branch_list.key(@current_branch)
  end

  class BranchGroup
    def initialize
      @branch_list = Hash.new
      master = Branch.new
      @branch_list["master"] = master
      @current_branch = master
      @current_branch_name = "master"
    end

    attr_reader :current_branch, :branch_list

    def create(branch_name)
      if @branch_list.has_key?(branch_name)
        ReturnObject.new(false, "Branch #{branch_name} already exists.")
      else
        new_branch = Branch.new(@current_branch)
        @branch_list[branch_name] = new_branch
        ReturnObject.new(true, "Created branch #{branch_name}.")
      end
    end

    def checkout(branch_name)
      if @branch_list.has_key?(branch_name)
        @current_branch = @branch_list[branch_name]
        ReturnObject.new(true, "Switched to branch #{branch_name}.")
      else
        ReturnObject.new(false, "Branch #{branch_name} does not exist.")
      end
    end

    def remove(branch_name)
      if @branch_list.has_key?(branch_name)
        if branch_name == @branch_list.key(current_branch)
          ReturnObject.new(false, "Cannot remove current branch.")
        else
          @branch_list.delete(branch_name)
          ReturnObject.new(true, "Removed branch #{branch_name}.")
        end
      else
        ReturnObject.new(false, "Branch #{branch_name} does not exist.")
      end
    end

    def list
      branches_name_list = String.new
      @branch_list.keys.sort.each do |key|
        if key == @current_branch_name
          branches_name_list << "* #{key}\n"
        else
          branches_name_list << "  #{key}\n"
        end
      end
      ReturnObject.new(true, branches_name_list.chomp!)
    end

    class Branch
      def initialize(copy_branch = nil)
        if copy_branch.nil?
          @commits_list = Array.new
          @to_be_committed = Hash.new
          @head = nil
        else
          @commits_list = copy_branch.commits_list
          @to_be_committed = copy_branch.to_be_committed
          @head = copy_branch.head
        end
      end

      attr_accessor :head, :commits_list, :to_be_committed
    end
  end
end

class Commit
  def initialize(message, new_objects)
    @date = Time.now
    @message = message
    @hash = Digest::SHA1.hexdigest(date.to_s + message)
    @objects_hash = new_objects.clone
  end

  attr_reader :date, :message, :hash, :objects_hash

  def objects
    @objects_hash.values
  end

  def log_message
    correct_date_format = date.strftime('%a %b %-d %H:%M %Y %z')
    "Commit #{hash}\nDate: #{correct_date_format}\n\n\t#{message}\n\n"
  end
end

class ReturnObject
  def initialize(success, message, result = nil)
    @message = message
    @success = success

    unless result == nil
      @result = result
    end
  end

  attr_reader :message, :result

  def success?
    @success
  end

  def error?
    not @success
  end
end