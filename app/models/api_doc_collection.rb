class ApiDocCollection
  include Mongoid::Document
  include Mongoid::Tree
  include Mongoid::Tree::Traversal

  field :title, :type => String
  field :slug, :type => String
  field :url_path, :type => String
  field :summary, :type => String
  field :body, :type => String

  default_scope asc(:title)

  index :title => 1
  index :slug => 1
  index({ :url_path => 1 }, { :unique => true })

  validates :slug,
    :uniqueness => true

  has_many :api_doc_services

  before_save :generate_url_path

  def self.flattened_tree
    flattened = []
    self.traverse do |node|
      flattened << node
    end

    flattened
  end

  def sorted_ancestors
    self.ancestors.sort_by { |a| a.depth }
  end

  def sorted_ancestors_and_self
    self.ancestors.sort_by { |a| a.depth } + [self]
  end

  def api_doc_service_ids
    self.api_doc_services.map { |service| service.id }
  end

  def api_doc_service_ids=(new_ids)
    ApiDocService.where(:_id.in => self.api_doc_service_ids).update_all(:api_doc_collection_id => nil)
    ApiDocService.where(:_id.in => new_ids).update_all(:api_doc_collection_id => self.id)
  end

  def url_path
    @url_path ||= File.join(ActionController::Base.config.relative_url_root.to_s, self[:url_path])
  end

  def generate_url_path
    self.url_path = File.join("/doc", self.slug)
  end

  def to_label
    unless @to_label
      depth_prefix = "- " * 2 * self.depth
      @to_label = "#{depth_prefix}#{self.title}"
    end

    @to_label
  end
end
