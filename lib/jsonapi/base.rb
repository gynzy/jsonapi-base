require "jsonapi/base/version"

module JSONAPI
  module Base
    extend ActiveSupport::Concern

    included do
      if respond_to?(:hide_action)
        hide_action :alias_parsing
        hide_action :attributes
        hide_action :before_create
        hide_action :before_destroy
        hide_action :before_update
        hide_action :create_failure
        hide_action :create_success
        hide_action :destroy_failure
        hide_action :destroy_success
        hide_action :update_failure
        hide_action :update_success
        hide_action :model
        hide_action :parameter_aliases
      end

      if respond_to?(:before_action)
        before_action :alias_parsing
        before_action :before_create, only: [:create]
        before_action :before_update, only: [:update]
        before_action :before_destroy, only: [:destroy]
      end

    end

    def show
      resource = JSONAPI::FetchData::Resource.new(model).find(params)
      authorize resource

      include_param = params.fetch(:include, nil)
      render_model resource, include: include_param.nil? ? nil : include_param.scan(/[-\w]+/)
    end

    def index
      resources = JSONAPI::FetchData::Collection.new(policy_scope(model)).find(params).all

      serialize_attr = {
        include: params.fetch(:include, '').scan(/[-\w]+/),
        fields: params.fetch(:fields, {}).deep_symbolize_keys,
      }

      render_models resources, serialize_attr
    end

    def create
      resource = model.new(attributes)
      authorize resource

      if resource.valid?
        resource.save
        create_success(resource)
        render_model resource, status: 201
      else
        create_failure(resource)
        render_errors({ errors: resource.errors })
      end
    end

    def update
      resource = model.find(params[:id].to_i)
      authorize resource

      if resource && resource.update_attributes(attributes)
        update_success(resource)
        render_model resource, status: 201
      else
        update_failure(resource)
        render_errors({ errors: resource.errors })
      end
    end

    def destroy
      resource = model.find_by_id(params[:id])

      if resource
        authorize resource
        resource.destroy
        destroy_success(resource)
        render_model resource, status: 202
      else
        skip_authorization
        destroy_failure(resource)
        render_404('404')
      end
    end

    # This error will be given when there is no correct route found
    def action_not_found
      skip_authorization
      render_501
    end

    # private

    # overwrite to allow aliases in attributes
    def attributes
      return @attributes if defined?(@attributes)
      hash = params.require(:data).require(:attributes).permit(*policy(model).permitted_attributes)
      @attributes = HashKeys.deep_symbolize_and_underscore(hash)

      parameter_aliases.each do |k,v|
        @attributes[k] = @attributes.delete(v) if @attributes.has_key?(v)
      end if parameter_aliases.any?

      @attributes
    end

    # Create methods
    def before_create
    end

    def create_failure(resource)
    end

    def create_success(resource)
    end

    # Update methods
    def before_update
    end

    def update_failure(resource)
    end

    def update_success(resource)
    end

    # Destroy methods
    def before_destroy
    end

    def destroy_failure(resource)
    end

    def destroy_success(resource)
    end

    def alias_parsing
      if parameter_aliases.any?
        filters = params.fetch(:filter, {})
        sort = params.fetch(:sort, nil)

        params_aliases = {}
        parameter_aliases.each do |k,v|
          filters[k] = filters.delete(v) if filters.has_key?(v)
          sort.gsub!(v.to_s, k.to_s) if sort && (sort.length > 0)
        end
        params_aliases[:filter] = filters if filters.any?
        params_aliases[:sort] = sort unless sort.blank?
        params.merge!(params_aliases)
      end
    end

    def model
      controller_name.classify.constantize
    end

    def parameter_aliases
      {}
    end
  end
end
