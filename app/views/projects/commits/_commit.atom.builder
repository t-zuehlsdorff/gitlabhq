xml.entry do
  xml.id      project_commit_url(@project, id: commit.id)
  xml.link    href: project_commit_url(@project, id: commit.id)
  xml.title   truncate(commit.title, length: 80)
  xml.updated commit.committed_date.xmlschema
  xml.media   :thumbnail, width: "40", height: "40", url: image_url(avatar_icon(commit.author_email))

  xml.author do |author|
    xml.name commit.author_name
    xml.email commit.author_email
  end

  xml.summary markdown(commit.description, pipeline: :single_line)
end
