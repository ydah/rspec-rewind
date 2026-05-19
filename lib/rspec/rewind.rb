# frozen_string_literal: true

require_relative 'rewind/core'

RSpec::Rewind.install! unless RSpec::Rewind.auto_install_disabled?
