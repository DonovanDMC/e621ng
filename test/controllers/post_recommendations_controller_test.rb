# frozen_string_literal: true

require "test_helper"

class PostRecommendationsControllerTest < ActionDispatch::IntegrationTest
  context "The post recommendations controller" do
    setup do
      @user = create(:user)
    end

    context "show action" do
      should "render" do
        get post_recommendations_path
        assert_response :success
      end

      should "work with user_id" do
        stub_const(Recommender, "MIN_USER_FAVS", 1) do
          @posts = create_list(:post, 5)
          FavoriteManager.add!(user: @user, post: @posts.first)
          stub_request(:get, %r{\A#{Danbooru.config.recommender_server}/recommend}).to_return(body: @posts.map { |p| [p.id, rand(0.0..1.0)] }.to_json)
          get_auth post_recommendations_path, @user, params: { format: :json, user_id: @user.id }
          assert_response :success
          assert_same_elements(@posts[1..].pluck(:id), @response.parsed_body.pluck("id"))
        end
      end

      should "restrict user_id for hidden favorites" do
        stub_const(Recommender, "MIN_USER_FAVS", 1) do
          @posts = create_list(:post, 5)
          FavoriteManager.add!(user: @user, post: @posts.first)
          @user.update(enable_privacy_mode: true)
          stub_request(:get, %r{\A#{Danbooru.config.recommender_server}/recommend}).to_return(body: @posts.map { |p| [p.id, rand(0.0..1.0)] }.to_json)
          get_auth post_recommendations_path, create(:user), params: { format: :json, user_id: @user.id }
          assert_response :forbidden
        end
      end

      should "work with post_id" do
        stub_const(Recommender, "MIN_POST_FAVS", 1) do
          @posts = create_list(:post, 5)
          FavoriteManager.add!(user: @user, post: @posts.first)
          stub_request(:get, %r{\A#{Danbooru.config.recommender_server}/similar}).to_return(body: @posts.map { |p| [p.id, rand(0.0..1.0)] }.to_json)
          get_auth post_recommendations_path, @user, params: { format: :json, post_id: @posts.first.id }
          assert_response :success
          assert_same_elements(@posts[1..].pluck(:id), @response.parsed_body.pluck("id"))
        end
      end
    end
  end
end
