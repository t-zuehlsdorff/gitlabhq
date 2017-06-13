xml.title   "#{@project.name} issues"
xml.link    href: url_for(params), rel: "self", type: "application/atom+xml"
xml.link    href: namespace_project_issues_url(@project.namespace, @project), rel: "alternate", type: "text/html"
xml.id      namespace_project_issues_url(@project.namespace, @project)
xml.updated @issues.first.updated_at.xmlschema if @issues.reorder(nil).any?

xml << render(partial: 'issues/issue', collection: @issues) if @issues.reorder(nil).any?
