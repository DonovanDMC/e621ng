class AvoidPosting < ApplicationRecord
  belongs_to_creator
  belongs_to_updater

  has_many :versions, -> { order("avoid_posting_versions.id ASC") }, class_name: "AvoidPostingVersion", dependent: :destroy
  belongs_to :artist
  after_save :create_version

  scope :active, -> { where(is_active: true) }
  scope :deleted, -> { where(is_active: false) }

  def create_version
    AvoidPostingVersion.create({
      avoid_posting_id: id,
      details: details,
      staff_notes: staff_notes,
      is_active: is_active,
    })
  end

  def status
    if is_active?
      "Active"
    else
      "Deleted"
    end
  end

  module ApiMethods
    def hidden_attributes
      attr = super
      attr += %i[staff_notes] unless CurrentUser.is_janitor?
      attr
    end
  end

  module ArtistMethods
    delegate :group_name, :other_names, :other_names_string, :linked_user_id, :linked_user, :any_name_matches, to: :artist, allow_nil: true
    def artist_name
      artist&.name
    end

    def artist_name=(name)
      self.artist = Artist.find_or_create_by(name: name)
    end
  end

  module SearchMethods
    def artist_search(params)
      Artist.search(params.slice(:any_name_matches, :any_other_name_matches).merge({ id: params[:artist_id], name: params[:artist_name] }))
    end

    def search(params)
      q = super
      artist_keys = %i[artist_name artist_id any_name_matches any_other_name_matches]
      q = q.joins(:artist).merge(artist_search(params)) if artist_keys.any? { |key| params.key?(key) }

      q = q.attribute_matches(:details, params[:details])
      q = q.attribute_matches(:staff_notes, params[:staff_notes])
      q = q.attribute_matches(:is_active, params[:is_active])
      q = q.where_user(:creator_id, :creator, params)
      q = q.where("creator_ip_addr <<= ?", params[:creator_ip_addr]) if params[:creator_ip_addr].present?
      q.apply_basic_order(params)
    end
  end

  include ApiMethods
  include ArtistMethods
  extend SearchMethods
end
