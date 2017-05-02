module BlobViewer
  class Markup < Base
    include Rich
    include ServerSide

    self.partial_name = 'markup'
    self.extensions = Gitlab::MarkupHelper::EXTENSIONS
    self.binary = false
  end
end
