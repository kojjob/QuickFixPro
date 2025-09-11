module PaginationHelper
  def simple_paginate(collection_name, current_page, per_page = 25)
    current_page = current_page.to_i
    current_page = 1 if current_page < 1
    
    content_tag :div, class: "flex items-center justify-between border-t border-gray-200 bg-white px-4 py-3 sm:px-6" do
      content_tag :div, class: "flex flex-1 justify-between sm:hidden" do
        prev_link = if current_page > 1
          link_to "Previous", url_for(page: current_page - 1), 
                  class: "relative inline-flex items-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
        else
          content_tag :span, "Previous", 
                      class: "relative inline-flex items-center rounded-md border border-gray-300 bg-gray-100 px-4 py-2 text-sm font-medium text-gray-400 cursor-not-allowed"
        end
        
        next_link = link_to "Next", url_for(page: current_page + 1),
                           class: "relative ml-3 inline-flex items-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
        
        prev_link + next_link
      end + 
      content_tag(:div, class: "hidden sm:flex sm:flex-1 sm:items-center sm:justify-between") do
        content_tag(:div) do
          content_tag :p, class: "text-sm text-gray-700" do
            "Showing page ".html_safe +
            content_tag(:span, current_page, class: "font-medium")
          end
        end +
        content_tag(:div) do
          content_tag :nav, class: "isolate inline-flex -space-x-px rounded-md shadow-sm", "aria-label": "Pagination" do
            prev_button = if current_page > 1
              link_to url_for(page: current_page - 1), 
                      class: "relative inline-flex items-center rounded-l-md px-2 py-2 text-gray-400 ring-1 ring-inset ring-gray-300 hover:bg-gray-50 focus:z-20 focus:outline-offset-0" do
                content_tag(:span, "Previous", class: "sr-only") +
                content_tag(:svg, nil, class: "h-5 w-5", viewBox: "0 0 20 20", fill: "currentColor", "aria-hidden": "true") do
                  tag(:path, "fill-rule": "evenodd", d: "M12.79 5.23a.75.75 0 01-.02 1.06L8.832 10l3.938 3.71a.75.75 0 11-1.04 1.08l-4.5-4.25a.75.75 0 010-1.08l4.5-4.25a.75.75 0 011.06.02z", "clip-rule": "evenodd")
                end
              end
            else
              content_tag :span, 
                         class: "relative inline-flex items-center rounded-l-md px-2 py-2 text-gray-300 ring-1 ring-inset ring-gray-300 bg-gray-50 cursor-not-allowed" do
                content_tag(:span, "Previous", class: "sr-only") +
                content_tag(:svg, nil, class: "h-5 w-5", viewBox: "0 0 20 20", fill: "currentColor", "aria-hidden": "true") do
                  tag(:path, "fill-rule": "evenodd", d: "M12.79 5.23a.75.75 0 01-.02 1.06L8.832 10l3.938 3.71a.75.75 0 11-1.04 1.08l-4.5-4.25a.75.75 0 010-1.08l4.5-4.25a.75.75 0 011.06.02z", "clip-rule": "evenodd")
                end
              end
            end
            
            # Page numbers (show current page and a few around it)
            page_links = []
            if current_page > 2
              page_links << link_to("1", url_for(page: 1), 
                                   class: "relative inline-flex items-center px-4 py-2 text-sm font-semibold text-gray-900 ring-1 ring-inset ring-gray-300 hover:bg-gray-50 focus:z-20 focus:outline-offset-0")
              if current_page > 3
                page_links << content_tag(:span, "...", 
                                         class: "relative inline-flex items-center px-4 py-2 text-sm font-semibold text-gray-700 ring-1 ring-inset ring-gray-300 focus:outline-offset-0")
              end
            end
            
            ((current_page - 1)..(current_page + 1)).each do |page|
              next if page < 1
              if page == current_page
                page_links << content_tag(:span, page, 
                                         class: "relative z-10 inline-flex items-center bg-indigo-600 px-4 py-2 text-sm font-semibold text-white focus:z-20 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600")
              else
                page_links << link_to(page, url_for(page: page),
                                     class: "relative inline-flex items-center px-4 py-2 text-sm font-semibold text-gray-900 ring-1 ring-inset ring-gray-300 hover:bg-gray-50 focus:z-20 focus:outline-offset-0")
              end
            end
            
            next_button = link_to url_for(page: current_page + 1),
                                 class: "relative inline-flex items-center rounded-r-md px-2 py-2 text-gray-400 ring-1 ring-inset ring-gray-300 hover:bg-gray-50 focus:z-20 focus:outline-offset-0" do
              content_tag(:span, "Next", class: "sr-only") +
              content_tag(:svg, nil, class: "h-5 w-5", viewBox: "0 0 20 20", fill: "currentColor", "aria-hidden": "true") do
                tag(:path, "fill-rule": "evenodd", d: "M7.21 14.77a.75.75 0 01.02-1.06L11.168 10 7.23 6.29a.75.75 0 111.04-1.08l4.5 4.25a.75.75 0 010 1.08l-4.5 4.25a.75.75 0 01-1.06-.02z", "clip-rule": "evenodd")
              end
            end
            
            prev_button + page_links.join.html_safe + next_button
          end
        end
      end
    end
  end
end