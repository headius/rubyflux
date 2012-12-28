require 'rake/clean'

task :default => [:test]
task :test do
  puts "TODO: test!"
end

CLEAN.include 'build'

desc "Runs a single file"
task :run, [:file_name] => [:compile] do |t, args|
  Dir.chdir("#{File.dirname(__FILE__)}")
  file_name = args[:file_name]
  raise "must specify file to run" unless file_name && File.exists?(file_name)
  Dir.chdir("#{File.dirname(__FILE__)}/build")
  sh "java #{File.basename(file_name, '.rb')}"
end

desc "Generate the java source file"
task :generate, [:file_name] => [:jruby_check] do |t, args|
  Dir.chdir("#{File.dirname(__FILE__)}")
  file_name = args[:file_name]
  raise "must specify file to generate" unless file_name && File.exists?(file_name)
  sh "jruby -I target:src/main/ruby src/main/ruby/ruby_flux.rb #{file_name}"
end

desc "Compile the java source to bytecode"
task :compile, [:file_name] => [:generate] do |t, args|
  Dir.chdir("#{File.dirname(__FILE__)}")
  file_name = args[:file_name]

  raise "must specify file to compile" unless file_name && File.exists?(file_name)
  Dir.chdir("#{File.dirname(__FILE__)}/build")
  sh "javac #{File.basename(file_name, '.rb')}.java"
end


task :jruby_check do |t|
  raise "Must have jruby installed" if `which jruby`.strip.empty?
end
