class Tempfile
  def persist
    ::ObjectSpace.undefine_finalizer(self)
  end
end
