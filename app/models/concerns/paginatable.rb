# frozen_string_literal: true

module Paginatable
  extend ActiveSupport::Concern

  included do
    # Ensure Kaminari is included for pagination
    include Kaminari::ActiveRecordModelExtension if defined?(Kaminari::ActiveRecordModelExtension)
  end
end
