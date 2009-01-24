module FormatHelper

  def datetime_format(datetime)
    datetime.strftime(RetroCM[:content][:format][:datetime])
  end

  def date_format(datetime)
    datetime.strftime(RetroCM[:content][:format][:date])
  end

  def time_format(datetime)
    datetime.strftime(RetroCM[:content][:format][:time])
  end

  def boolean_format(value, t_yes = nil, t_no = nil)
    title = value ? (t_yes || _('Yes')) : (t_no || _('No'))
    image_tag value.to_s + '.png', :title => title, :alt => title
  end

  def maximum_attachment_size
    number_to_human_size(RetroCM[:general][:attachments][:max_size].kilobytes)
  end

  def time_interval_in_words(to_time = 0, from_time = Time.zone.now, include_seconds = false)
    from_time = from_time.to_time if from_time.respond_to?(:to_time)
    to_time = to_time.to_time if to_time.respond_to?(:to_time)
    interval = distance_of_time_in_words(from_time, to_time, include_seconds)        
    from_time < to_time ? _('in {{period}}', :period => interval) : _('{{period}} ago', :period => interval)
  end

  def markup(text, options = {})
    options.symbolize_keys!
    wikified = sanitize(WikiEngine.markup(text.dup, options[:engine]))
    format_internal_links(wikified, options)
  end
    
  def simple_markup(text, options = {})
    wikified = auto_link(simple_format(escape_once(text.dup)))
    format_internal_links(wikified, options)
  end

  def markup_area(name, method, options = {}, html_options = {})
    markup_preview("#{name}_#{method}") + markup_editor(name, method, options, html_options) 
  end

  protected 

    def markup_editor(name, method, options = {}, html_options = {})
      html_options.reverse_merge!(
        :onkeydown => 'return catchTab(this,event);', 
        :rows => 10, :cols => 40)
  
      content_tag :div, 
        text_area(name, method, html_options) + links_for_markup_editor("#{name}_#{method}"), 
        :id => "#{name}_#{method}_editor",
        :class => 'markup-editor'
    end

    def links_for_markup_editor(element_id)
      markup_link = link_to _('Markup reference'), markup_reference_path,
        :popup => [
          _('Markup reference'), 
          'height=400,width=800,location=0,status=0,menubar=0,resizable=1,scrollbars=1'
        ]    
      preview_link = link_to_remote _('Preview'), 
        :url => markup_preview_path,
        :with => "'content=' + escape($F('#{element_id}')) + '&element_id=#{element_id}_preview'",
        :complete => "Element.hide('#{element_id}_editor'); Element.show('#{element_id}_preview_container'); "
  
      content_tag :div, markup_link + ' | ' + preview_link, :class => 'markup-links'
    end

    def markup_preview(element_id)
      preview_tag = content_tag :div, '', 
        :id => "#{element_id}_preview", 
        :class => 'markup markup-preview'    
          
      content_tag :div, preview_tag + link_for_markup_preview(element_id),
        :style => 'display: none;', 
        :id => "#{element_id}_preview_container"
    end

    def link_for_markup_preview(element_id)
      js_call = "Element.hide('#{element_id}_preview_container'); Element.show('#{element_id}_editor');"
      content_tag :div, link_to_function(_('Close preview'), js_call), 
        :class => 'markup-links'
    end
    
    def format_internal_links(markup, options = {})
      return markup if Project.current.blank? and not options[:demo] 
      
      WikiEngine.with_text_parts_only(markup) do |text|
        text.gsub(/([^\[]|^)\[(\\?)([\#|r]?)(\w+)\]([^\]]|$)/) do |match|
          prefix, escape, type, ref, suffix = $1, $2, $3, $4, $5
          case escape.blank? && type
          when 'r', ''
            prefix + format_internal_changeset_link(ref, options) + suffix
          when '#'
            prefix + format_internal_ticket_link(ref.to_i, options) + suffix
          else
            "#{prefix}[#{type}#{ref}]#{suffix}"
          end
        end
      end
    end
    
    def format_internal_changeset_link(revision, options = {})
      label = h("[#{revision}]")
      return link_to_function(label) if options[:demo]

      if User.current.permitted?(:changesets, :view) &&
         Project.current.changesets.exists?(:revision => revision)
        link_to label, project_changeset_path(Project.current, revision)
      else
        label
      end    
    end
  
    def format_internal_ticket_link(ticket_id, options = {})
      label = h("[##{ticket_id}]")      
      return link_to_function(label) if options[:demo]

      project = User.current.permitted?(:tickets, :view) ? find_project_for_ticket(ticket_id) : nil
      return label unless project
  
      info = project.existing_tickets[ticket_id]
      link_class = case info[:state]
        when 2 then 'ticket-in-progress'
        when 3 then 'ticket-resolved'
        else        'ticket-open'
        end                                        
      link_to label, project_ticket_path(project, ticket_id),
        :class => link_class, 
        :title => h(info[:summary])
    end

  private 

    def find_project_for_ticket(ticket_id)
      projects = RetroCM[:content][:markup][:global_ticket_refs] ? User.current.active_projects : [Project.current]
      projects.find do |project|
        !project.existing_tickets[ticket_id].blank?
      end
    end

end