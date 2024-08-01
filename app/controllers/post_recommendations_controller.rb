# frozen_string_literal: true

class PostRecommendationsController < ApplicationController
  respond_to :json, :html
  before_action :validate_enabled

  def show
    limit = params.fetch(:limit, 50).to_i.clamp(1, 320)
    sp = search_params
    sp[:post_id] = params[:post_id] if params[:post_id].present?
    sp[:user_id] = params[:user_id] if params[:user_id].present?
    @recs = Recommender.search(sp).take(limit)
    @posts = @recs.pluck(:post)

    respond_with(@recs) do |format|
      format.json { render json: @posts.to_json }
    end
  end

  private

  def search_params
    permit_search_params(%i[user_name user_id post_id max_recommendations post_tags_match])
  end

  def validate_enabled
    raise FeatureUnavailable unless Recommender.enabled?
  end
end
