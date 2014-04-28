#!/usr/bin/env ruby
# encoding: utf-8

require 'fileutils'

class Env
  attr_accessor :syms

  HOME_DIR = ENV['HOME']
  DOTFILES_DIR = "#{ENV['HOME']}/.dotfiles"

  def initialize
    @syms = [ ]
  end

  # print and flush immediately
  def print_and_flush(msg)
    print msg
    $stdout.flush
  end
  #
  # print and sleep a little while
  def print_with_sleep(str, sleep_time = 0.20)
    sleep sleep_time
    print_and_flush str
  end

  # checks if a command exists
  def command_exists?(name)
    `which #{name}`
    $?.success?
  end

  # clone a repo from github and returns true on success, false otherwise
  def github_clone?(*repo_info)
    unless command_exists?("git")
      puts "Can't find git, install git first.."
      false
    else
      github_repo_src = "https://github.com/#{repo_info.shift}"
      github_repo_dest = repo_info.shift

      print_and_flush "Cloning from #{github_repo_src} "

      # creates thread to clone from github repository
      clone_thread = Thread.new do
        if github_repo_dest.nil?
          `git clone #{github_repo_src} >/dev/null 2>&1`
        else
          `git clone #{github_repo_src} #{github_repo_dest} >/dev/null 2>&1`
        end
      end

      while clone_thread.alive?
        animate_progress_rotation
      end
      clone_thread.join

      $?.success?
    end
  end

  # animating the rotation of a bar to inidicate the progress of an operation
  def animate_progress_rotation
    print_with_sleep "-"
    print_with_sleep "\b\\"
    print_with_sleep "\b|"
    print_with_sleep "\b/"
    print_with_sleep "\b-"
    print_with_sleep "\b\\"
    print_with_sleep "\b|"
    print_with_sleep "\b."
  end

  # check if the name sym exists as a file, a directory or a symlink
  def sym_exists?(sym)
    File.exists?(sym) || File.directory?(sym) || File.symlink?(sym)
  end

  # forces a symlink of name 'sym_dest' to be created even if a file, directory or
  # a symlink with the same name already exists
  def force_symlink_create(sym_src, sym_dest)
    if File.directory?(sym_dest)
      sym_dest = "#{File.dirname(sym_dest)}/."
    end
    FileUtils.ln_s(sym_src, sym_dest, :force => true)
  end

  # downlaod dotfiles if the $HOME/.dotfiles directory doesn't exist
  def download_dotfiles
    unless File.directory? "#{HOME_DIR}/.dotfiles"
      puts "dotfiles do not exist in #{HOME_DIR}"
      puts "Trying to download dotfiles"
      unless github_clone?("amilaperera/dotfiles")
        abort "Failed to download dotfiles."
      else
        puts "Successfully downloaded dotfiles."
      end
    end
  end

  # create symbolic links from dotfiles to homedir
  def create_sym_links
    forceall, noforceall = false, false
    syms.each do |sym|
      sym_src, sym_dest = "#{DOTFILES_DIR}/#{sym}", "#{HOME_DIR}/#{sym}"
      unless sym_exists?(sym_src)
        abort "#{sym_src} doesn't exist. Consider downloading dotfiles again.."
      else

        if forceall
          puts "Forcefully creating symbolic link #{sym_dest}"
        elsif noforceall
          puts "Skip creating symbolic link #{sym_dest}"
        else
          puts "Creating symbolic link #{sym_dest}"
        end

        if sym_exists?(sym_dest)
          # if the symlink exists
          unless noforceall
            begin
              unless forceall
                print_and_flush "Replace #{sym_dest} with #{sym_src} (y|n|ya|na) ? "
                reply = gets.chomp.downcase
                forceall = true if reply == 'ya'
                noforceall = true if reply == 'na'
              end
              # create a symlink forcefully
              force_symlink_create(sym_src, sym_dest) if reply == 'y' || forceall
            rescue Exception => e
              abort "oops! symlink exists..failed to create symlink. #{e.message}"
            end
          end
        else
          # if the symlink does not exist
          begin
            FileUtils.ln_s(sym_src, sym_dest)
          rescue Exception => e
            abort "oops! failed to create symlink. #{e.message}"
          end
        end
      end
    end
  end
end

# Bash setup
class BashEnv < Env
  def initialize
    super
    %w(.bashrc .bash_profile .bash_logout .bash .inputrc).each { |e| syms.push e }
  end

  # setup the bash environment
  def setup_env
    puts
    puts "Setting up bash environment"
    puts "==========================="

    puts "Checking for dotfiles .."
    download_dotfiles

    puts
    puts "Creating symbolic links .."
    create_sym_links
  end
end

# ZShell setup
class ZshEnv < Env
  OH_MY_ZSH_DIR = "#{ENV['HOME']}/.oh-my-zsh"

  def initialize
    super
    %w(.zshrc).each { |e| syms.push e }
  end

  # download personal oh-my-zsh fork
  def download_ohmyzsh_fork
    if File.directory?(OH_MY_ZSH_DIR)
      puts "#{OH_MY_ZSH_DIR} already exists.."
      print_and_flush "Remove directory and reinstall (y|n) ? "
      if %w(yes y).include?(gets.chomp.downcase)
        begin
          FileUtils.rm_r(OH_MY_ZSH_DIR, :force => true)
          unless github_clone?("amilaperera/oh-my-zsh", OH_MY_ZSH_DIR)
            abort "Failed to download .oh-my-zsh"
          end
        rescue
          abort "error in reinstalling #{OH_MY_ZSH_DIR}"
        end
      end
    else
      puts "Downloading oh-my-zsh"
      unless github_clone?("amilaperera/oh-my-zsh", OH_MY_ZSH_DIR)
        abort "Failed to download .oh-my-zsh"
      end
    end
  end

  # create .zshrc file
  def create_zshrc
    if File.exists?("#{OH_MY_ZSH_DIR}/custom/template/.zshrc")
      begin
        FileUtils.ln_s("#{OH_MY_ZSH_DIR}/custom/template/.zshrc",
                       "#{ENV['HOME']}/.zshrc", :force => true)
      rescue Exception => e
        abort "oops! failed to create symlink. #{e.message}"
      end
    else
      abort "#{OH_MY_ZSH_DIR}/custom/template/.zshrc doesn't exist."
    end
  end

  # downloas the zsh-users plugins
  def download_zsh_users_plugins
    if File.directory?("#{OH_MY_ZSH_DIR}/custom")
      unless File.directory?("#{OH_MY_ZSH_DIR}/custom/plugins")
        begin
          Dir.mkdir("#{OH_MY_ZSH_DIR}/custom/plugins")
        rescue Exception => e
          abort "oops! failed to create directory. #{e.message}"
        end
      end
      begin
        FileUtils.mkdir_p("#{OH_MY_ZSH_DIR}/custom/plugins/zsh-syntax-highlighting")
        unless github_clone?("zsh-users/zsh-syntax-highlighting.git", "#{OH_MY_ZSH_DIR}/custom/plugins/zsh-syntax-highlighting")
          abort "Failed to download zsh-syntax-highlighting.git"
        end
        puts
        FileUtils.mkdir_p("#{OH_MY_ZSH_DIR}/custom/plugins/zsh-completions")
        unless github_clone?("zsh-users/zsh-completions.git", "#{OH_MY_ZSH_DIR}/custom/plugins/zsh-completions")
          abort "Failed to download zsh-syntax-completions"
        end
      rescue Exception => e
        abort "oops! failed to create directory. #{e.message}"
      end
    else
      abort "#{OH_MY_ZSH_DIR}/custom does not exist."
    end
  end

  # create symlinks to the completion files
  def create_symlinks_to_completions(*args)
    custom_plugin_dir = "#{OH_MY_ZSH_DIR}/custom/plugins"
    args.each do |arg|
      completion_file = "#{OH_MY_ZSH_DIR}/custom/plugins/zsh-completions/src/_#{arg}"
      unless File.exists?(completion_file)
        puts "#{completion_file} doesn't exist"
      else
        begin
          FileUtils.mkdir_p("#{custom_plugin_dir}/#{arg}")
          FileUtils.ln_s("#{completion_file}", "#{custom_plugin_dir}/#{arg}", :force => true)
        rescue Exception => e
          abort "Failed in file operation. #{e.message}"
        end
      end
    end
  end

  # setup the zsh environment
  def setup_env
    puts
    puts "Setting up zsh environment"
    puts "=========================="

    puts "Checking for oh-my-zsh .."
    download_ohmyzsh_fork

    puts
    puts "Downloading syntax-highlighting and zsh-completions from zsh-users .."
    download_zsh_users_plugins

    puts
    puts "Create symlinks to completion functions of ag, ack .."
    create_symlinks_to_completions('ag', 'ack')

    puts
    puts "Creating .zshrc .."
    create_zshrc
  end
end

# Vim environment setup
class VimEnv < Env
  def initialize
    super
    %w(.vimrc .gvimrc).each { |e| syms.push e }
  end

  # download bundles that are in the .vimrc file
  def download_bunldes
    forceall, noforceall, bundle_found = false, false, false
    bundle_root = "#{ENV['HOME']}/.vim/bundle"

    # create bundle dir if it doesn't exist
    unless File.directory?(bundle_root)
      begin
        FileUtils.mkdir_p(bundle_root)
      rescue
        puts "Can't create #{bundle_root}"
      end
    end

    # read .vimrc and install the bundles
    File.readlines("#{ENV['HOME']}/.vimrc").each do |line|
      # NOTE: the following regex needs Ruby version >= 1.9.2
      # if /^Bundle ('|")(?<repo>.*)\/(?<bundle>.*)('|")/ =~ line
      #
      # changing to a regexp that is compatible with ruby 1.8.7
      if /^Bundle ('|")(.*)\/(.*)('|")/ =~ line
        repo, bundle = Regexp.last_match(2), Regexp.last_match(3)
        bundle_found = true
        bundle_dir_name = "#{bundle_root}/#{bundle}"
        if File.directory?(bundle_dir_name)
          unless noforceall
            unless forceall
              print_and_flush "#{bundle_dir_name} exists.\nReinstall #{bundle} (y|n|ya|na) ? "
              reply = gets.chomp.downcase
              forceall = true if reply == 'ya'
              noforceall = true if reply == 'na'
            end
            if reply == 'y' || forceall
              begin
                FileUtils.rm_r(bundle_dir_name)
                unless github_clone?("#{repo}/#{bundle}", "#{bundle_dir_name}")
                  abort "Failed to download #{repo}/#{bundle}"
                end
                puts
              rescue
                abort "error redownloading #{repo}/#{bundle}"
              end
            end
          end
        else
          puts "Downloading #{bundle_dir_name}"
          unless github_clone?("#{repo}/#{bundle}", "#{bundle_dir_name}")
            abort "Failed to download #{repo}/#{bundle}"
          end
          puts
        end
      end
    end
    puts "No bundles found in #{ENV['HOME']}/.vimrc" unless bundle_found
  end

  # creates a symlink in bundle/autoload directory to pathogen
  def setup_pathogen
    autoload_dir, pathogen_dir = "#{ENV['HOME']}/.vim/autoload", "#{ENV['HOME']}/.vim/bundle/vim-pathogen"
    begin
      unless File.directory?(pathogen_dir)
        puts "pathogen doesn't exist in bundle directory\nTry to install pathogen first.."
      else
        unless File.directory?(autoload_dir)
          FileUtils.mkdir_p(autoload_dir)
        end
        FileUtils.ln_s("#{pathogen_dir}/autoload/pathogen.vim", "#{autoload_dir}/pathogen.vim", :force => true)
      end
    rescue
      abort "Failed to setup pathogen properly."
    end
  end

  # setup vim environment
  def setup_env
    puts
    puts "Setting up vim environment"
    puts "=========================="

    puts "Checking for dotfiles .."
    download_dotfiles

    puts
    puts "Creating symlinks .."
    create_sym_links

    puts
    puts "Downloading bundles .."
    download_bunldes

    puts
    puts "Setting up pathogen .."
    setup_pathogen
  end
end

# Rvm environment setup
class RvmEnv < Env
  def initialize
    super
  end

  def check_for_prq
    abort "Can't find curl. Install curl first." unless command_exists?('curl')
    abort "Can't find git. Install git first." unless command_exists?('git')
  end

  def install_rvm
    `\\curl -sSL https://get.rvm.io | bash -s stable`
    if $?.success?
      puts "Rvm installed successfully"
      `source ~/.profile`
    else
      abort "Failed to install Rvm"
    end
  end

  def setup_env
    puts
    puts "Setting rvm"
    puts "==========="

    puts "Checking for prerequisites before installing rvm .."
    check_for_prq

    puts "Installing rvm .."
    install_rvm
  end

end

class PonySayEvn < Env
  PONYSAY_DOWNLOAD_DIR = "/tmp/ponysay"
  def initialize
  end

  def setup_env
    unless github_clone?("erkin/ponysay", PONYSAY_DOWNLOAD_DIR)
      abort "Failed to download ponysay"
    end

    abort "Can't find python3" unless command_exists?("python3")
    Dir.chdir(PONYSAY_DOWNLOAD_DIR) do
      puts
      `sudo python3 setup.py --freedom=partial install >/dev/null 2>&1`
      if $?.success?
        puts "Ponysay installation succeeded"
      else
        abort "Ponysay installation failed"
      end
      puts
    end
  end
end

# Miscellaneous environment setup
# this includes the settings related to tmux, irb, ack, ag etc.
class MiscEnv < Env
  def initialize
    super
    %w(.tmux.conf .irbrc .ackrc .agignore .colordiffrc .gitconfig).each { |e| syms.push e }
  end

  def setup_env
    puts "Creating basic setup(irbc, tmux, ack, ag, colordiff, git configuration etc.) .."
    create_sym_links
  end

end

# The Setup class
# This acts like a context class
class SetupEnv
  attr_accessor :setup_env

  def initialize(setup)
    @setup_env = setup
  end

  def setup
    @setup_env.setup_env
  end
end

# main program
reply = ""
puts
puts "Environment Setup"
puts "================="
begin
  puts " 1. Zsh Environment"
  puts " 2. Bash Environment"
  puts " 3. Vim Environment"
  puts " 4. Rvm Environment"
  puts " 5. PonySay"
  puts " 6. Miscellaneous Settings"
  puts " Q. Quit"
  puts
  print " Choice ? "
  reply = gets.chomp.downcase

  unless %w(quit q).include?(reply)
    case reply
    when "1"
      SetupEnv.new(ZshEnv.new).setup
    when "2"
      SetupEnv.new(BashEnv.new).setup
    when "3"
      SetupEnv.new(VimEnv.new).setup
    when "4"
      SetupEnv.new(RvmEnv.new).setup
    when "5"
      SetupEnv.new(PonySayEvn.new).setup
    when "6"
      SetupEnv.new(MiscEnv.new).setup
    else
      puts " Bad Choice.."
    end
  end
end while not %w(quit q).include?(reply)