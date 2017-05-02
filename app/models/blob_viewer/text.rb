module BlobViewer
  class Text < Base
    include Simple
    include ServerSide

    self.partial_name = 'text'
    self.binary = false
    self.max_size = 1.megabyte
    self.absolute_max_size = 10.megabytes
  end
end
