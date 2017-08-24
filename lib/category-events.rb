module ::CategoryEvents
  class Engine < ::Rails::Engine
    engine_name "category_events"
    isolate_namespace CategoryEvents
  end
end

CategoryEvents::Engine.routes.draw do
  get ":category_id" => "event#events_for_category"
end

Discourse::Application.routes.append do
  mount ::CategoryEvents::Engine, at: "events"
end

class CategoryEvents::EventController < ApplicationController
  def events_for_category
    params.require[:category_id]
    params.permit[:period]

    opts = { :category_id => params[:category_id] }

    if params.include?(:period)
      opts[:period] = params[:period]
    end

    events = CategoryEventsHelper.events_for_category(opts)

    render_serialized(events, CategoryEvents::EventSerializer)
  end
end

class CategoryEvents::EventSerializer < ApplicationSerializer
  attributes :title, :start, :end, :url

  def start
    Time.at(object.topic.custom_fields['event_start']).iso8601
  end

  def end
    Time.at(object.topic.custom_fields['event_end']).iso8601
  end
end

module CategoryEventsHelper
  class << self
    def events_for_category(category_id, opts = {})
      topics = Topic.joins("INNER JOIN topic_custom_fields
                            ON topic_custom_fields.topic_id = topics.id
                            AND (topic_custom_fields.name = 'event_start'
                                OR topic_custom_fields.name = 'event_end')")
      topics = topics.where(category_id: category_id)
      events = []

      topics.each do |t|
        event_start = t.custom_fields['event_start']
        event_end = t.custom_fields['event_end']

        within_period = case opts[:period]
                        when 'upcoming'
                          event_start >= Time.now.iso8601
                        when 'past'
                          event_end < Time.now.iso8601
                        else
                          true
                        end

        if within_period
          events.push(t)
        end

        events
      end
    end
  end
end
