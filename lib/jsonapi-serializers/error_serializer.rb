require 'set'
require 'active_support/inflector'

module JSONAPI
  module ErrorSerializer
    OPTIONAL_TOP_LEVEL_ATRIBUTES = [:id, :links, :status, :code, :title, :detail, :source, :meta]

    def self.included(target)
      target.send(:include, InstanceMethods)
      target.extend ClassMethods
      target.class_eval do
        include JSONAPI::Attributes
      end
    end

    module ClassMethods
      def serialize(object, options = {})
        # Since this is being called on the class directly and not the module, override the
        # serializer option to be the current class.
        options[:serializer] = self

        JSONAPI::ErrorSerializer.serialize(object, options)
      end
    end

    module InstanceMethods
      attr_accessor :error
      attr_accessor :object
      attr_accessor :context

      def initialize(object, options = {})
        @object = object
        @context = options[:context] || {}
      end

      def id; end
      def links; end
      def status; end
      def code; end

      # Override this to provide error-object title.
      # Returns error's message by default
      def title
        @object.message
      end

      def detail; end
      def source; end

      # Override this to provide resource-object metadata.
      # http://jsonapi.org/format/#document-structure-resource-objects
      def meta
      end
    end

    def self.find_serializer_class_name(object)
      "#{object.class.name}Serializer"
    end

    def self.find_serializer_class(object)
      class_name = find_serializer_class_name(object)
      class_name.constantize
    end

    def self.find_serializer(object)
      find_serializer_class(object).new(object)
    end

    def self.serialize(objects, options = {})
      # Normalize option strings to symbols.
      options[:is_collection] = options.delete('is_collection') || options[:is_collection] || false
      options[:serializer] = options.delete('serializer') || options[:serializer]
      options[:context] = options.delete('context') || options[:context] || {}
      options[:skip_collection_check] = options.delete('skip_collection_check') || options[:skip_collection_check] || false
      options[:meta] = options.delete('meta') || options[:meta]

      # An internal-only structure that is passed through serializers as they are created.
      passthrough_options = {
        context: options[:context],
        serializer: options[:serializer],
      }

      if !options[:skip_collection_check] && options[:is_collection] && !objects.respond_to?(:each)
        raise JSONAPI::Serializer::AmbiguousCollectionError.new(
                'Attempted to serialize a single object as a collection.')
      end

      # Spec: Primary data MUST be either:
      # - a single resource object or null, for requests that target single resources.
      # - an array of resource objects or an empty array ([]), for resource collections.
      # http://jsonapi.org/format/#document-structure-top-level
      if options[:is_collection] && !objects.any?
        primary_data = []
      elsif !options[:is_collection] && objects.nil?
        primary_data = nil
      elsif options[:is_collection]
        # Have object collection.
        passthrough_options[:serializer] ||= find_serializer_class(objects.first)
        primary_data = serialize_primary_multi(objects, passthrough_options)
      else
        # Duck-typing check for a collection being passed without is_collection true.
        # We always must be told if serializing a collection because the JSON:API spec distinguishes
        # how to serialize null single resources vs. empty collections.
        if !options[:skip_collection_check] && objects.respond_to?(:each)
          raise JSONAPI::Serializer::AmbiguousCollectionError.new(
                  'Must provide `is_collection: true` to `serialize` when serializing collections.')
        end
        # Have single object.
        passthrough_options[:serializer] ||= find_serializer_class(objects)
        primary_data = serialize_primary(objects, passthrough_options)
      end
      primary_data = [primary_data] unless primary_data.kind_of?(Array)
      result = {
        'errors' => primary_data,
      }
      result['meta'] = options[:meta] if options[:meta]
      result
    end

    def self.serialize_primary(object, options = {})
      serializer_class = options.fetch(:serializer)
      serializer = serializer_class.new(object, options)

      data = {}

      # Merge in optional top-level members if they are non-nil.
      # http://jsonapi.org/format/#error-objects
      JSONAPI::ErrorSerializer::OPTIONAL_TOP_LEVEL_ATRIBUTES.each do |attribute|
        data.merge!({attribute.to_s => serializer.send(attribute)}) unless serializer.send(attribute).nil?
      end
      data
    end
    class << self; protected :serialize_primary; end

    def self.serialize_primary_multi(objects, options = {})
      # Spec: Primary data MUST be either:
      # - an array of resource objects or an empty array ([]), for resource collections.
      # http://jsonapi.org/format/#document-structure-top-level
      return [] if !objects.any?

      objects.map { |obj| serialize_primary(obj, options) }
    end
    class << self; protected :serialize_primary_multi; end
  end
end
