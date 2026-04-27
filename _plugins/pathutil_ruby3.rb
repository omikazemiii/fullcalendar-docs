# Patch pathutil 0.16.x for Ruby 3 keyword arguments.
#
# Jekyll 3 depends on pathutil and calls Pathutil#read while starting the watch
# server. pathutil forwards keyword arguments as a positional hash, which Ruby 3
# no longer accepts for File.read/write helpers.
class Pathutil
  def read(*args, **kwd)
    kwd[:encoding] ||= encoding

    content = File.read(self, *args, **kwd)
    normalize[:read] ? content.encode(:universal_newline => true) : content
  end

  def binread(*args, **kwd)
    kwd[:encoding] ||= encoding

    content = File.binread(self, *args, **kwd)
    normalize[:read] ? content.encode(:universal_newline => true) : content
  end

  def write(data, *args, **kwd)
    data = data.encode(:crlf_newline => true) if normalize[:write]
    File.write(self, data, *args, **kwd)
  end

  def binwrite(data, *args, **kwd)
    data = data.encode(:crlf_newline => true) if normalize[:write]
    File.binwrite(self, data, *args, **kwd)
  end
end

module Jekyll
  class Document
    private

    def read_content(opts)
      self.content = File.read(path, **Utils.merged_file_read_opts(site, opts))
      if content =~ YAML_FRONT_MATTER_REGEXP
        self.content = $POSTMATCH
        data_file = SafeYAML.load(Regexp.last_match(1))
        merge_data!(data_file)
      end
    end
  end

  module Convertible
    def read_yaml(base, name, opts = {})
      @base = base
      @name = name

      path = @path || site.in_source_dir(base, name)
      self.content = File.read(path, **Utils.merged_file_read_opts(site, opts))
      if content =~ Document::YAML_FRONT_MATTER_REGEXP
        self.content = $POSTMATCH
        self.data = SafeYAML.load(Regexp.last_match(1))
      end

      self.data ||= {}
    rescue SyntaxError => e
      Jekyll.logger.warn "YAML Exception reading #{File.join(base, name)}: #{e.message}"
    rescue Exception => e
      Jekyll.logger.warn "Error reading file #{File.join(base, name)}: #{e.message}"
    end
  end

  module Tags
    class IncludeTag
      def read_file(file, context)
        File.read(file, **file_read_opts(context))
      end
    end
  end
end
