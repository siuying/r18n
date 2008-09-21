=begin
Locale to i18n support.

Copyright (C) 2008 Andrey “A.I.”" Sitnik <andrey@sitnik.ru>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
=end

require 'pathname'
require 'yaml'

module R18n
  # Information about locale (language, country and other special variant
  # preferences). Locale was named by RFC 3066. For example, locale for French
  # speaking people in Canada will be +fr_CA+.
  #
  # Locale files is placed in <tt>locales/</tt> dir in YAML files.
  #
  # Each locale has +sublocales+ – often known languages for people from this
  # locale. For example, many Belorussians know Russian and English. If there
  # is’t translation for Belorussian, it will be searched in Russian and next in
  # English translations.
  #
  # == Usage
  #
  # Get Russian locale and print it information
  #
  #   ru = R18n::Locale.new('ru')
  #   ru['title']        #=> "Русский"
  #   ru['code']         #=> "ru"
  #   ru['direction']    #=> "ltr"
  #
  # == Available data
  #
  # * +code+: locale RFC 3066 code;
  # * +title+: locale name on it language;
  # * +direction+: writing direction, +ltr+ or +rtl+ (for Arabic and Hebrew);
  # * +sublocales+: often known languages for people from this locale;
  # * +pluralization+: function to get pluralization type for +n+ items;
  # * +include+: locale code to include it data, optional.
  #
  # You can see more available data about locale in samples in
  # <tt>locales/</tt> dir.
  class Locale
    LOCALES_DIR = Pathname(__FILE__).dirname.expand_path + '../../locales/'

    # All available locales
    def self.available
      Dir.glob(LOCALES_DIR + '*.yml').map do |i|
        File.basename(i, '.yml')
      end
    end
    
    # Is +locale+ has info file
    def self.exists?(locale)
      File.exists?(File.join(LOCALES_DIR, locale + '.yml'))
    end
    
    # Default pluralization rule to translation without locale file
    def self.default_pluralize(n)
      n == 0 ? 0 : n == 1 ? 1 : 'n'
    end

    # Load locale by RFC 3066 +code+
    def initialize(code)
      code.delete! '/'
      code.delete! '\\'
      
      @locale = {}
      while code
        file = LOCALES_DIR + "#{code}.yml"
        raise "Locale #{code} isn't exists" if not File.exists? file
        loaded = YAML.load_file(file)
        @locale = loaded.merge @locale
        code = loaded['include']
      end
      
      eval("def pluralize(n); #{@locale["pluralization"]}; end", binding)
    end

    # Get information about locale
    def [](name)
      @locale[name]
    end

    # Is another locale has same code
    def ==(locale)
      @locale['code'] == locale['code']
    end

    # Human readable locale code and title
    def inspect
      "Locale #{@locale['code']} (#{@locale['title']})"
    end
    
    # Returns the integer in String form, according to the rules of the locale.
    # It will also put real typographic minus.
    def format_number(number)
      str = number.to_s
      str[0] = '−' if 0 > number # Real typographic minus
      group = self['numbers']['group_delimiter']
      
      if 'indian' == self['numbers']['separation']
        str.gsub(/(\d)(?=((\d\d\d)(?!\d))|((\d\d)+(\d\d\d)(?!\d)))/) do |match|
          match + group
        end
      else
        str.gsub(/(\d)(?=(\d\d\d)+(?!\d))/) do |match|
          match + group
        end
      end
    end
    
    # Returns the float in String form, according to the rules of the locale.
    # It will also put real typographic minus.
    def format_float(float)
      decimal = self['numbers']['decimal_separator']
      self.format_number(float.to_i) + decimal + float.to_s.split('.').last
    end
    
    # Same that <tt>Time.strftime</tt>, but translate months and week days
    # names. In +time+ you can use Time, DateTime or Date object. In +format+
    # you can use String with standart +strftime+ format (see
    # <tt>Time.strftime</tt> docs) or Symbol with format from locale file
    # (<tt>:time</tt>, <tt>:date</tt>, <tt>:short_data</tt>, <tt>:long_data</tt>,
    # <tt>:datetime</tt>, <tt>:short_datetime</tt> or <tt>:long_datetime</tt>).
    def strftime(time, format)
      if Symbol == format.class
        format = self['formats'][format.to_s]
      end
      
      translated = ''
      format.scan(/%[EO]?.|./o) do |c|
        case c.sub(/^%[EO]?(.)$/o, '%\\1')
        when '%A'
          translated << self['week']['days'][time.wday]
        when '%a'
          translated << self['week']['abbrs'][time.wday]
        when '%B'
          translated << self['months']['names'][time.month - 1]
        when '%b'
          translated << self['months']['abbrs'][time.month - 1]
        when '%p'
          translated << if time.hour < 12
            self['time']['am']
          else
            self['time']['pm']
          end
        else
          translated << c
        end
      end
      time.strftime(translated)
    end

    # Return pluralization type for +n+ items. It will be replacing by code
    # from locale file.
    def pluralize(n); end
  end
end