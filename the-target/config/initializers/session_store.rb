# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_the-target_session',
  :secret      => 'b9864fb662b4e2e255f064a5774854040ef58876cb8aae41c207edfb8be4de70c28fcc2a09811f07df0852685ecdbf3237fdb1c2ea83173643e2f3336e4ab6f8'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
