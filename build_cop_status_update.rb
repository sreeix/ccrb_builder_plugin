require 'rest_client'
require 'json'
class BuildCopStatusUpdate < BuilderPlugin
  def initialize(project = nil)
    @project = project
    @hostname =`curl -s http://169.254.169.254/latest/meta-data/instance-id`.strip
    
  end
  # Called by Project at the start of a new build before any other build events.
  def build_initiated
    @start = Time.now
  end

  # Called by Project after some basic logging and the configuration_modified check and just before the build begins running, 
  def build_started(build)
    gem_file = File.join(build.project.path, 'work',"Gemfile")
    if(File.exists?(gem_file))
      puts "Gemfile found for the project, installing it"
      `BUNDLE_GEMFILE=#{gem_file} bundle install`
    else
      puts "Assuming Rails old versions and running rake gems:install"
      `cd #{File.join(build.project.path, 'work')} && rake gems:install`
    end
    rest_put(build, :current_status => :building)
    
  end
  
  # Called by Project immediately after the build has finished running.
  def build_finished(build)
    rest_put(build, :current_status => (build.successful? ? :success : :failure),
               :last_build_on => DateTime.now,
               :last_build_status => project.last_complete_build_status,
               :last_build_time => Time.now - @start)
  end
  
  # Called by Project after the completion of a build if the previous build was successful and this one is a failure.
  def build_broken(build, previous_build)
    rest_put (build, :current_status => :failed)
  end
  
  # Called by Project after the completion of a build if the previous build was a failure and this one was successful.
  def build_fixed(build, previous_build)
    rest_put build, :current_status => :success
  end
  
  # Called by Project if the build fails internally with a CC.rb exception.
  def build_loop_failed(exception)
    rest_put build, :current_status => :failed
  end


  # Called by ChangeInSourceControlTrigger to indicate that it is about to poll source control.
  def polling_source_control
  end
  
  # Called by ChangeInSourceControlTrigger to indicate that no new revisions have been detected.
  def no_new_revisions_detected
  end
  
  # Called by ChangeInSourceControlTrigger to indicate that new revisions were detected.
  def new_revisions_detected(revisions)
  end
  
  # Called by Project to indicate that a build has explicitly been requested by the user.
  def build_requested
  
  end  
  
  # Called by BuildSerializer if it another build is still running and it cannot acquire the build serialization lock.
  # It will retry until it times out. Occurs only if build serialization is enabled in your CC.rb configuration.
  def queued
  end
  
  # Called by BuildSerializer if it times out attempting to acquire the build serialization lock due to another build
  # still running. Occurs only if build serialization is enabled in your CC.rb configuration.
  def timed_out
  end
  
  
  # Called by Project at the start of a new build to indicate that the configuration has been modified,
  # after which the build is aborted.
  def configuration_modified
  end
  
  # Called by Project at the end of a build to indicate that the build loop is once again sleeping.
  def sleeping
  end
  
  def rest_put(build, args)
    puts "throwing some data to the #{buildcop_url}/#{@hostname}/#{build.project.name} -> #{args.inspect}"
    RestClient.put "#{buildcop_url}/build_loop/#{@hostname}/#{build.project.name}", args
  end
  def buildcop_url
    @@bc_url ||= JSON.parse(File.read('/etc/buildcop/dna.json'))['server']['host_url']
  end
end

Project.plugin :build_cop_status_update