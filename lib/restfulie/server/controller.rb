#
#  Copyright (c) 2009 Caelum - www.caelum.com.br/opensource
#  All rights reserved.
# 
#  Licensed under the Apache License, Version 2.0 (the "License"); 
#  you may not use this file except in compliance with the License. 
#  You may obtain a copy of the License at 
#  
#   http://www.apache.org/licenses/LICENSE-2.0 
#  
#  Unless required by applicable law or agreed to in writing, software 
#  distributed under the License is distributed on an "AS IS" BASIS, 
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
#  See the License for the specific language governing permissions and 
#  limitations under the License. 
#
module Restfulie::Server::Cache
  
  class Config

    def allow(seconds)
      @max_age = seconds
      self
    end

    def max_age
      @max_age ||= 0
    end
  end
end

module ActionController
  class Base

    def self.cache
      @cache_config ||= Restfulie::Server::Cache::Config.new
    end
    
    def cache
      @cache_config ||= Restfulie::Server::Cache::Config.new
    end
    
    # adds cache-control header and returns true if the resource requires rendering
    def handle_cache_headers(resource)
      response.headers['Cache-control'] = "max-age=#{cache_to_use(resource).max_age}"
      stale? resource.cache_info
    end

    # renders an specific resource to xml
    # using any extra options to render it (invoke to_xml).
    def render_resource(resource, options = {}, render_options = {})

      return nil unless handle_cache_headers(resource)

      return render(render_options) if render_options[:text]

      options[:controller] = self
      respond_to do |format|
        add_media_responses(format, resource, options, render_options)
      end

    end

     # renders a resource collection, making full use of atom support
     def render_collection(collection, &block)
       if block
         content = collection.to_atom(:title =>collection_name, :controller => self) do |item|
           block.call item
         end
       else
         content = collection.to_atom(:title => collection_name, :controller => self)
       end
       render_resource collection, nil, {:content_type => 'application/atom+xml', :text => content}
     end

     # returns the name of this controllers collection
     def collection_name
       self.class.name[/(.*)Controller/,1]
     end

     def add_media_responses(format, resource, options, render_options)
       types = Restfulie::MediaType.default_types
       types = resource.class.media_types if resource.class.respond_to? :media_types
       types.each do |media_type|
         add_media_response(format, resource, media_type, options, render_options)
       end
     end

     def add_media_response(format, resource, media_type, options, render_options)
       controller = self
       format.send media_type.short_name.to_sym do
         media_type.execute_for(controller, resource, options, render_options)
       end
     end

    # adds support to rendering resources, i.e.:
    # render :resource => @order, :with => { :except => [:paid_at] }
    alias_method :old_render, :render
    def render(options = nil, extra_options = {}, &block)
      resource = options[:resource] unless options.nil?
      unless resource.nil?
        render_resource(resource, options[:with])
      else
        old_render(options, extra_options)
      end
    end
    
    # renders a created resource including its required headers:
    # Location and 201
    def render_created(resource, options = {})
      location= url_for resource
      render_resource resource, options, {:status => :created, :location => location}
    end

    private
    
    # returns cache config to use, either an overriden local one for this controller and model
    # or a generic one
    def cache_to_use(resource)
      if respond_to?(:configure_cache)
        configure_cache(resource)
        cache
      else
        self.cache
      end
    end

  end
  
  module MimeResponds
    class Responder
      attr_reader :mime_type_priority
      alias_method :old_respond, :respond unless method_defined?(:old_respond)
      def respond
        RestfulieResponder.new.respond(self)
      end
    end
    
    class RestfulieResponder
      def respond(instance)
        instance.old_respond unless instance.mime_type_priority.include? "html"
      end
    end
  end
end
