class Api::RateLimit
  include Mongoid::Document

  # Fields
  field :_id, :type => String, :overwrite => true, :default => lambda { SecureRandom.uuid }
  field :duration, :type => Integer
  field :accuracy, :type => Integer
  field :limit_by, :type => String
  field :limit, :type => Integer
  field :distributed, :type => Boolean
  field :response_headers, :type => Boolean

  # Relations
  embedded_in :settings

  # Validations
  validates :duration,
    :presence => true,
    :numericality => { :greater_than => 0 },
    :uniqueness => { :scope => :limit_by }
  validates :accuracy,
    :presence => true,
    :numericality => { :greater_than => 0 }
  validates :limit_by,
    :presence => true,
    :inclusion => { :in => %w(ip apiKey) }
  validates :limit,
    :presence => true,
    :numericality => { :greater_than => 0 }
  validates :distributed,
    :presence => true

  # Callbacks
  before_validation :auto_calculate_accuracy
  before_validation :auto_calculate_distributed

  private

  def auto_calculate_accuracy
    if(self.duration.present?)
      duration_seconds = self.duration / 1000.0

      accuracy_seconds = nil
      if(duration_seconds <= 1.second)
        accuracy_seconds = 0.5.seconds
      elsif(duration_seconds <= 30.seconds)
        accuracy_seconds = 1.second
      elsif(duration_seconds <= 2.minutes)
        accuracy_seconds = 5.seconds
      elsif(duration_seconds <= 10.minutes)
        accuracy_seconds = 30.seconds
      elsif(duration_seconds <= 1.hour)
        accuracy_seconds = 1.minute
      elsif(duration_seconds <= 10.hours)
        accuracy_seconds = 10.minutes
      elsif(duration_seconds <= 1.day)
        accuracy_seconds = 30.minutes
      elsif(duration_seconds <= 2.days)
        accuracy_seconds = 1.hour
      elsif(duration_seconds <= 7.days)
        accuracy_seconds = 6.hours
      else
        accuracy_seconds = 1.day
      end

      self.accuracy = accuracy_seconds.seconds * 1000
    end

    true # Return true so the before_validation callback doesn't abort
  end

  def auto_calculate_distributed
    if(self.duration && self.duration >= 10_000)
      self.distributed = true
    else
      self.distributed = false
    end

    true # Return true so the before_validation callback doesn't abort
  end
end
