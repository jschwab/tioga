# This small script makes tioga.sty and lib/TexPreamble.rb from
# tioga.sty.in

require 'date'

# We make up the color constants from the Tioga file.
require_relative '../lib/Tioga/ColorConstants.rb'

# Generate colors
color_specs = "% Color constants, generated from ColorConstants.rb\n"
for const in Tioga::ColorConstants.constants
  r,g,b = *Tioga::ColorConstants.const_get(const)
  color_spec = sprintf "{%0.3f,%0.3f,%0.3f}", r,g,b
  color_specs += "\\definecolor{#{const}}{rgb}#{color_spec}\n"
end

# slurp up the lines from tioga.sty.in
i = File.open("misc/tioga.sty.in")
lines = i.readlines
i.close

puts "Generating lib/Tioga/TexPreamble.rb"
out = File.open("lib/Tioga/TexPreamble.rb", "w")
out.print <<EOCOMMENT
# This file is automatically generated from Tioga/tioga.sty.in 
# using the Tioga/mk_tioga_sty.rb script.
# 
# Please do not modify this file directly as all changes would
# be lost !! 

EOCOMMENT
out.print "module Tioga
  class FigureMaker
    TEX_PREAMBLE = <<'End_of_preamble'\n" + 
"\\makeatletter\n" +  
lines.join +  
"\n\\makeatother\nEnd_of_preamble\n" + 
"    COLOR_PREAMBLE = <<'End_of_preamble'\n" +
color_specs + "\nEnd_of_preamble\n" + 
"  end\nend"

out.close

date = Date::today
str_date = sprintf "%04d/%02d/%02d", date.year, date.month, date.day


puts "Generating misc/tioga.sty"
out = File.open("misc/tioga.sty", "w")
out.puts "\\ProvidesPackage{tioga}[#{str_date}]"
out.puts lines.join
out.puts color_specs
out.close
