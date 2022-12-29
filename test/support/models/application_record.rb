class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  # After saving, always force a full re-read of the record from the database.
  # While not the most efficient, this ensures the test suite always reads in
  # default values set by the database or fields that are updated by triggers
  # after saving. By default, ActiveRecord does not read these values, so it
  # can lead to inconsistent records with unexpected null values.
  #
  # See: https://github.com/rails/rails/issues/17605
  after_commit :reload
end
