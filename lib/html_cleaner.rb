# -*- encoding: utf-8 -*-
require 'nokogiri'
require 'amatch'
require 'iconv'

class HtmlCleanerError < RuntimeError
end

class HtmlStatistics

  def initialize(document, smoothing_factor=1)
    @smoothing_factor = smoothing_factor
    @lines = split_and_truncate_document(document, smoothing_factor)
  end

  # This smooths and decimates the data by a factor of
  # the smoothing_factor. So if the smoothing factor is 4 then
  # it will be 4 times smaller.
  def smooth_and_decimate
    n = 0
    h = []
    @lines.each_slice(@smoothing_factor) do |slice|
      line_lengths = slice.map { |l| len = l.strip.size; (len < 80) ? 0 : len }
      h << [n, (sum(line_lengths) / @smoothing_factor) * scaling_factor(@lines.size / @smoothing_factor, n)]
      n += 1
    end
    h
  end

  # Find the area under the curve for each peak. A peak is defined as having
  # a start line count of more than zero and end line count of zero.
  def auc(h)
    peaks = []

    m = 0
    x = 0
    intermediate_sum = 0
    calculating = false

    h.each do |n,v|
      if v > 0.0 && calculating == true         # peak processing.
        intermediate_sum += v
        m += 1
      elsif v > 0.0 && calculating == false     # start of peak processing.
        intermediate_sum += v
        calculating = true
        m += 1
        x = n
      elsif v == 0.0 && calculating == true     # end of peak, calculate the area.
        peaks << [(intermediate_sum), x, x + m]
        m = 0
        intermediate_sum = 0
        calculating = false
      elsif v == 0.0 && calculating == false    # zero value so discard it.
        next
      end
    end
    peaks
  end

  # Sorts out which 'peaks' to keep and which to discard based on some heuristics.
  # It applies two heuristics:
  #   1. only keep peaks with an area of between the maximum and 50% of the maximum
  #   2. only keep peaks that a with twice the distance (X axis) of the first peak
  def extract_lines_to_keep(peaks, decimation_factor)
    sorted_peaks = peaks.sort { |a,b| b[0] <=> a[0] }
    partition_point = (sorted_peaks[0][0] / 2.0).floor
    truncated_sorted_peaks = sorted_peaks.partition {|a| a[0] > partition_point }

    partition_point = truncated_sorted_peaks[0].sort { |a,b| a[1] <=> b[1] }[0][1]

    peaks_biased_to_origin = truncated_sorted_peaks[0].partition { |a| a[1] < partition_point * 2 }

    peaks_biased_to_origin[0].sort { |a,b| a[1] <=> b[1] }.map{ |p| (p[1] * decimation_factor)..(p[2] * decimation_factor) }
  end

  # Used for debugging.
  def print_with_line_numbers
    @lines.each_with_index do |l,n|
      print "%-4d %s\n" % [n, l.strip]
    end
  end

  # Extract the specified lines from the original document. line_ranges
  # is and array of ranges.
  def extract_line_numbers(line_ranges)
    line_ranges.reduce([]) do |acc, line_range|
      acc << @lines.slice(line_range)
      acc << "\n\n"
    end
  end

  private

  # Splits the document into lines and truncates it to
  # ensure it is modulo the smoothing factor.
  def split_and_truncate_document(document, smoothing_factor)
    lines = document.lines.to_a
    remainder = lines.size % smoothing_factor
    lines.slice(0, lines.size - remainder)
  end

  # Calulate the sum of the given array.
  def sum(d)
    d.inject { |sum,x| sum ? sum + x : x }
  end

  # Adds a weight to each line. The weight is a linear function based on line
  # number; the further from the origin the lower the weight.
  def scaling_factor(total_size, n)
    (total_size.to_f - n.to_f) / total_size.to_f**2
  end
end

class HtmlCleaner

  ELEMENTS_TO_REMOVE = ['img', 'script', 'noscript', 'head', 'meta', 'option', 'link', 'br', 'style', '[@style=\'display: none\']']
  ELEMENTS_TO_KEEP = ['strong','font','h1','h2','h3','h4','h5','h6','b','i','a','cite','code','em','q','s','span','strike','sub','super','tt']

  # This assumes the document is alreay in utf-8.
  def initialize(html)

    # TODO translate html entitiy references.
    # Get rid of entity references and a few other characters.
    # WARNING. Be careful of the  when cutting & pasting.
    @document = Nokogiri(html.gsub(/(&#?[[:alnum:]]+;|[|])/, ''))
  end

  def title
    if @title.nil?
      @title = @document.search('//title').inner_text.split.join(" ").gsub(/\s+/, ' ').strip rescue ''
    end
    @title
  end

  def html
    @document.to_s
  end

  def encoding?
    @document.encoding
  end

  # Entry point for processing a document. It removes any unwanted
  # elements and then calls the main process method. Finally it performs
  # some cleanup once the document has been processed.
  def content

    # Get the title before we break the document!
    title

    begin
      (@document/ELEMENTS_TO_REMOVE.join(",")).remove
      extract_child(@document)
      z = @document.inner_text
      s = remove_short_lines(@document.inner_text)
      stats = HtmlStatistics.new(s, 4)
      h = stats.smooth_and_decimate
      a = stats.auc(h)

      if a.empty?
        final_doc = s
      else
        line_ranges = stats.extract_lines_to_keep(a, 4)
        final_doc = stats.extract_line_numbers(line_ranges).join
      end

      final_cleanup(final_doc)
    rescue RuntimeError
      # There appears to be a bug in ruby 1.9.1 that causes a "no implicit
      # conversion from nil to integer (TypeError)" in String#each_line. All
      # the times that has happened have been on documents that are useless
      # so it isn't a major problem as the moment. Just return an empty string
      # as there is nothing more that can usefully be done.
      ""
    end
  end

  private

  # Main processing method. This code recurses through the document
  # checking to see if each element (text, processing instructions, etc
  # are ignored) has children. If it does it performs a cluster analysis
  # and short element analysis, removing elements as appropriate.
  def extract_child(elem)
    # We are only interested in the elements
    elements = child_elements(elem)

    if elements.empty?
      return
    else
      elements.each do |element|
        child_elements = child_elements(element)
        remove_elements(cluster_distance(child_elements))
        extract_child(element)

        # This removes line feeds from elements that just contain text. This
        # is a naive implementation but it does help when word wrap is set to
        # smaller then that considered 'short' by the short element user.
        if element.children.size == 1
          case element.name
          when /h[1-6]/, 'font', 'pre', 'code', 'pre', 'tt', 'b', 'i', 'p'
            element.content = element.inner_text.gsub(/\s/, ' ')
          end
        end
      end
    end
  end

  # Returns all the child elements for a particular element.
  def child_elements(element)
    element.children.select { |c| c.is_a?(Nokogiri::XML::Element) }
  end

  # Calculates the average hamming distance for the all elements and then calculates
  # which documents to keep based on the heuristics in add_element_to_results
  def cluster_distance(elements)
    return [] if elements.size < 3

    results = {:keep => Nokogiri::XML::NodeSet.new(Nokogiri::XML::Document.new),
               :discard => Nokogiri::XML::NodeSet.new(Nokogiri::XML::Document.new)}

    elements = elements.to_a
    previous_element = elements.shift

    elements.each_with_index do |element,n|
      m = Amatch::Hamming.new(process_path(previous_element.path))
      distance = m.match(process_path(element.path))

      results = add_element_to_results(results, previous_element, distance)
      results = add_element_to_results(results, element, distance) if n == elements.length - 1 # last element

      previous_element = element
    end
    return results[:discard]
  end

  # Work out whether to keep or discard the element. It uses the hamming
  # distance and the length of the text in each element.
  def add_element_to_results(results, element, distance)
    if distance == 0
      if element.inner_text.gsub(/&#[0-9]{2,4};/, '').gsub(/\s+/, ' ').length > 80
        results[:keep] << element
      else
        results[:discard] << element
      end
    else
      results[:keep] << element
    end
    return results
  end

  # Cleans up the output. This is a bit hacky but the whole process
  # is based on heuristics and arbitrary observations.
  # TODO Clean this up a bit. Different documents have very different
  # spacing.
  def final_cleanup(s)
    substitutions = [
      # collapse spaces into one.
      [/[ \t]+/, " "],
      # replace cr + lf with lf
      [/\r\n/, "\n"],
      # Remove any whitespace on a line
      [/^\s*$/, ""],
      # replace multiple lf's (paragraph break) with a cr to keep track of them
      [/\n+/, "\r"],
      # replace single lf's with white space
      [/\n/, ' '],
      # delete whitespaces at line beginnings
      [/^\s*/, ''],
      # finally, re-expand paragraph breaks (cr) to double lf
      [/\r/, "\n\n"]]

    s = s.gsub(/<.*doctype.*>/m, "")

    # This cleans all those words and short sentences that don't
    # get removed by the scrubber itself.
    output = []
    s.each_line { |l| output << l if l.strip.length > 80 || !/\w+/.match(l) }

    output = output.join
    substitutions.each { |from, to| output.gsub!(from, to) }

    return output
  end

  def remove_short_lines(s)
    s.each_line.inject([]) do |acc,l|
      line = l.strip
      acc << line if line.length > 50 || !/\w+/.match(line)
      acc
    end.join("\n")
  end

  # Helper method. Remove an array of elements.
  def remove_elements(elements)
    elements.each { |e| e.remove }
  end

  # Helper method. Removes attributes from the xpath.
  def process_path(s)
    begin
      s.gsub(/\[(@[a-zA-Z].*?|[0-9]+)\]/, '')
    rescue
      raise HtmlCleanerError, "Document too long", caller
    end
  end
end
