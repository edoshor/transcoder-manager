require 'mina/bundler'
require 'mina/rails'
require 'mina/git'
require 'mina/rbenv'

set :domain, 'staging'
set :deploy_to, '/var/www/transcoder-manager'
set :repository, 'https://github.com/edoshor/transcoder-manager'
set :branch, 'master'
set :shared_paths, %w(config/thin.yml config/logging-production.yml)
set :user, 'deploy'

set :rbenv_path, '/usr/local/rbenv'
task :environment do
  # required for system wide installation of rbenv
  queue %{export RBENV_ROOT=#{rbenv_path}}

  invoke :'rbenv:load'
end

task :setup => :environment do
  queue! %[mkdir -p "#{deploy_to}/shared/log"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/shared/log"]

  queue! %[mkdir -p "#{deploy_to}/shared/config"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/shared/config"]

  queue! %[touch "#{deploy_to}/shared/config/thin.yml"]
  queue %[echo "-----> Be sure to edit 'shared/config/thin.yml'."]

  queue! %[touch "#{deploy_to}/shared/config/logging-production.yml"]
  queue %[echo "-----> Be sure to edit 'shared/config/logging-production.yml'."]
end

desc 'Deploys the current version to the server.'
task :deploy => :environment do
  deploy do
    invoke :'git:clone'
    invoke :'deploy:link_shared_paths'
    invoke :'bundle:install'

    to :launch do
      queue %{
          if [ -f $(cat config/thin.yml | grep pid: | sed '/^pid: */!d; s///;q') ];
          then
            echo "thin is up. restarting"
            bundle exec thin -C config/thin.yml restart
            exit
          else
            echo "thin is down. starting"
            bundle exec thin -C config/thin.yml start
            exit
          fi
      %}
    end
  end
end
