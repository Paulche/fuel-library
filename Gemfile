source 'https://rubygems.org'

group :development, :test do
  gem 'puppetlabs_spec_helper',               :require => 'false'
  gem 'rspec', '~>3.3',                       :require => 'false'
  gem 'rspec-puppet', '~> 2.2.0',             :require => 'false'
  gem 'metadata-json-lint',                   :require => 'false'
  gem 'mime-types', '2.6.2',                  :require => 'false' # 3.0+ requires ruby 2.0
  gem 'puppet-lint-param-docs',               :require => 'false'
  gem 'puppet-lint-absolute_classname-check', :require => 'false'
  gem 'puppet-lint-absolute_template_path',   :require => 'false'
  gem 'puppet-lint-unquoted_string-check',    :require => 'false'
  gem 'puppet-lint-leading_zero-check',       :require => 'false'
  gem 'puppet-lint-variable_contains_upcase', :require => 'false'
  gem 'puppet-lint-numericvariable',          :require => 'false'
  gem 'puppet_facts',                         :require => 'false'
  gem 'json',                                 :require => 'false'
  gem 'pry',                                  :require => 'false'
  gem 'simplecov',                            :require => 'false'
  gem 'webmock',                              :require => 'false'
  gem 'fakefs',                               :require => 'false'
  gem 'fog-google', '0.1.0',                  :require => 'false' # 0.1.1+ requires ruby 2.0
  gem 'beaker-rspec',                         :require => 'false'
  gem 'beaker-puppet_install_helper',         :require => 'false'

end

if puppetversion = ENV['PUPPET_GEM_VERSION']
  gem 'puppet', puppetversion, :require => false
else
  # TODO(aschultz): remove this version when 4 is supported
  gem 'puppet', '~> 3.8', :require => false
end
