# frozen_string_literal: true

require 'dry/monads/do'
require 'dry/monads/result'

class Operation
  include Dry::Monads::Do
  include Dry::Monads::Result::Mixin
  include Dry::Monads[:maybe]
  extend Dry::Initializer
end
