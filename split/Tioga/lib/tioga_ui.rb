# tpc.rb -- Tioga-Point-and-Click interface based on Ruby/Tk

=begin
   Copyright (C) 2007  Bill Paxton

   This file is part of Tioga.

   Tioga is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Library Public License as published
   by the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   Tioga is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU Library General Public License for more details.

   You should have received a copy of the GNU Library General Public License
   along with Tioga; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
=end

require 'Tioga/tioga.rb'

class TiogaUI  
  
  include Tioga
  
  def fm
    FigureMaker.default
  end
  
  
  def check_have_loaded
    return true if @have_loaded
    append_to_log "Must open a file first!"
    return false
  end
  
  
  def make_all_pdfs
    return unless check_have_loaded
    fm.num_figures.times { |i| 
        if fm.figure_pdfs[i] == nil
          require_pdf(i)
        end
      }
  end
  
  def make_portfolio(view = true)
    return unless check_have_loaded
    name = @title_name + '_portfolio'
    append_to_log "#{name}\n"
    make_all_pdfs
    portfolio_name = fm.make_portfolio(name)
    return unless view
    view_pdf(portfolio_name)
    return if @batch_mode
    return unless $mac_command_key
    append_to_log "\nNote: Preview fails to make updated thumbnails after a Revert for a portfolio,"
    append_to_log "so for now you'll have to Close and redo Open as a workaround.\n"
  end


  def require_pdf(num)
    begin
      append_to_log fm.figure_names[num] + "\n"
      result = fm.require_pdf(num)
      return result
    rescue
      puts "error return from require_pdf"
      return nil
    end
  end
  
  
  def preview(num)
    result = require_pdf(num)
    return result if $pdf_viewer == nil
    syscmd = "cp " + result + " " + @pdf_name
    system(syscmd)
    saveInHistory(num)
    return view_pdf(@pdf_name)
  end
  
  
  def show_in_own_window
    view_pdf(fm.figure_pdfs[@listBox.curselection[0]])
  end


  def view_pdf(pdf_file)
    if pdf_file == nil
      raise 'view_pdf called with nil'
    end
    system($pdf_viewer + ' ' + pdf_file + " > /dev/null")
  end
  
  
  def figureSelected
    preview(@listBox.curselection[0])
  end


  def loadfile(fname, reselect=true)
    @have_loaded = false
    fm.reset_state
    begin
      
      append_to_log "loading #{fname}\n"
      load(fname) # this should define the TiogaFigures class
      num_fig = fm.num_figures
      if num_fig == 0 
          raise "Failed to define any figures.  ' +
            'Remember to invoke 'new' for the class containing the figure definitions"
      end
      
      @title_name = fname.split('/')[-1]
      @title_name = @title_name[0..-4] if @title_name[-3..-1] == ".rb"
      fname = fname[0..-4] if fname[-3..-1] == ".rb"
      @pdf_name = fname + ".pdf"
      @have_loaded = true
      
      return if @batch_mode
      
      @root.title('Tioga:' + @title_name)
      @listBox.delete(0, 'end')
      fm.figure_names.each { |name| @listBox.insert('end', name) }
      set_selection(0) if reselect
      
    rescue Exception => er
      report_error(er, "ERROR: load failed for #{fname}\n")
    end
  end

  
  def report_error(er, msg)
    append_to_log msg
    append_to_log " "
    append_to_log "    " + "#{er.message}"
    line_count = 0
    er.backtrace.each do |line|
        if line_count < fm.num_error_lines
            append_to_log "    " + line
        end
        line_count = line_count + 1
    end
  end
  
  
  def set_selection(num)
    @listBox.see(num)
    @listBox.selection_clear(0,'end')
    @listBox.selection_set(num)
    figureSelected
  end
  
  
  def reload
    return unless check_have_loaded
    selection = @listBox.curselection[0]
    name = (selection.kind_of?(Integer))? fm.figure_names[selection] : nil
    loadfile(@tioga_filename, false)
    num = fm.figure_names.index(name)
    unless num.kind_of?(Integer)
      reset_history
      num = 0
    end
    set_selection(num)
  end 

  
  def next_in_list
    return unless check_have_loaded
    num = @listBox.curselection[0] + 1
    num = 0 if num >= @listBox.size
    set_selection(num)
  end

  
  def prev_in_list
    return unless check_have_loaded
    num = @listBox.curselection[0] - 1
    num = @listBox.size - 1 if num < 0
    set_selection(num)
  end


  def resetHistory
    @history_loc = -1
    @history_len = 0
    @forward_back = false
  end
 
 
  def saveInHistory(num)
    if @forward_back
      forward_back = false
      return
    end
    return if (@history_len > 0 && @history_loc >= 0 && @history[@history_loc] == num)
    @history_len = @history_loc + 2
    @history_loc = @history_len - 1
    @history[@history_loc] = num
  end


  def back
    return if (@history_loc <= 0 || @history_len == 0)
    @history_loc = @history_loc - 1
    @forward_back = true
    set_selection(@history[@history_loc])
  end


  def forward
    return if (@history_loc + 1 >= @history_len)
    @history_loc = @history_loc + 1
    @forward_back = true
    set_selection(@history[@history_loc])
  end
  
  
  def eval
    begin
        str = @evalEntry.get
        append_to_log "eval " + str
        result = fm.eval_function(str)
        append_to_log result.to_s + "\n"
    rescue Exception => er
      report_error(er, "ERROR: eval failed for #{str}\n")
    end
  end
  
  
  def append_to_log(str)
    if @batch_mode
      puts str
      return
    end
    return if @logText == nil
    return unless str.kind_of?String
    @logText.insert('end', str + "\n")
    @logText.see('end')
  end

 
  def openDocument
    filetypes = [["Ruby Files", "*.rb"]]
    filename = Tk.getOpenFile('filetypes' => filetypes,
                              'parent' => @root)
    return unless (filename.kind_of?String) && (filename.length > 0)
    set_working_dir(filename)
    loadfile(filename)
  end


  def addFileMenu(menubar)
    fileMenuButton = TkMenubutton.new(menubar,
                                      'text' => 'File',
                                      'background' => 'WhiteSmoke',
                                      'underline' => 0)
    fileMenu = TkMenu.new(fileMenuButton, 'tearoff' => false)
 
    fileMenu.add('command',
                 'label' => 'Open',
                 'command' => proc { openDocument },
                 'underline' => 0,
                 'accel' => @accel_key + '+O')
    @root.bind(@bind_key + '-o', proc { openDocument })
         
 
    fileMenu.add('command',
                 'label' => 'Reload',
                 'command' => proc { reload },
                 'underline' => 0,
                 'accel' => @accel_key + '+R')
    @root.bind(@bind_key + '-r', proc { reload })
 
    fileMenuButton.menu(fileMenu)
    fileMenuButton.pack('side' => 'left')
  end
  
  
  def addToolsMenu(menubar)
    toolsMenuButton = TkMenubutton.new(menubar,
                                      'text' => 'Tools',
                                      'background' => 'WhiteSmoke',
                                      'underline' => 0)
    toolsMenu = TkMenu.new(toolsMenuButton, 'tearoff' => false)
    
    acc = ($mac_osx)
 
    toolsMenu.add('command',
                 'label' => 'Portfolio PDF',
                 'command' => proc { make_portfolio },
                 'underline' => 0,
                 'accel' => @accel_key + '+P')
    @root.bind(@bind_key + '-p', proc { make_portfolio })
 
    toolsMenu.add('command',
                 'label' => 'Make All PDFs',
                 'command' => proc { make_all_pdfs },
                 'underline' => 0,
                 'accel' => @accel_key + '+M')
    @root.bind(@bind_key + '-m', proc { make_all_pdfs })
 
    toolsMenu.add('command',
                 'label' => 'Show in Own Window',
                 'command' => proc { show_in_own_window },
                 'underline' => 0,
                 'accel' => @accel_key + '+S')
    @root.bind(@bind_key + '-s', proc { show_in_own_window })
 
    toolsMenuButton.menu(toolsMenu)
    toolsMenuButton.pack('side' => 'left')
  end


  def addTiogaMenu(menubar)
    tiogaMenuButton = TkMenubutton.new(menubar,
                                      'text' => 'Tioga',
                                      'background' => 'WhiteSmoke',
                                      'underline' => 0)
    tiogaMenu = TkMenu.new(tiogaMenuButton, 'tearoff' => false)
 
    tiogaMenu.add('command',
                 'label' => 'About Tioga',
                 'command' => proc { showAboutBox },
                 'underline' => 0)
 
    tiogaMenu.add('separator')
 
    tiogaMenu.add('command',
                 'label' => 'Quit',
                 'command' => proc { exit },
                 'underline' => 0,
                 'accel' => @accel_key + '+Q')
    @root.bind(@bind_key + '-q', proc { exit })
 
    tiogaMenuButton.menu(tiogaMenu)
    tiogaMenuButton.pack('side' => 'left')
  end

 
  def showAboutBox
      Tk.messageBox('icon' => 'info', 'type' => 'ok',
        'title' => 'About Tioga-Point-and-Click',
        'parent' => @root,
        'message' => "Tioga-Point-and-Click is a Ruby/Tk Application.\n" +
            "It uses the Tioga kernel to create PDFs and then calls your favorite viewer to show them.\n\n" +
            "Version 0.1  -- January, 2007\n\n" +
            "Visit http://theory.kitp.ucsb.edu/~paxton/tioga.html")
  end


  def createMenubar(parent)
    menubar = TkFrame.new(parent) { background 'WhiteSmoke' }
    
    addTiogaMenu(menubar)
    addFileMenu(menubar)
    addToolsMenu(menubar)
 
    menubar.pack('side' => 'top', 'fill' => 'x', 'padx' => 8, 'pady' => 8)
  end
  
  
  def createLogText(parent)
    
    logFrame = TkFrame.new(parent) { background 'WhiteSmoke' }
    
    logText = TkText.new(logFrame) {
      borderwidth 0
      selectborderwidth 0
      height 6
      font $log_font
    }

    scrollBar = TkScrollbar.new(logFrame) { command proc { |*args| logText.yview(*args) } }
    logText.yscrollcommand(proc { |first, last| scrollBar.set(first, last) })
 
    scrollBar.pack('side' => 'right', 'fill' => 'y', 'pady' => 3)
    logText.pack('side' => 'right', 'fill' => 'both', 'expand' => true, 'pady' => 2)
    
    logFrame.pack('side' => 'right', 'fill' => 'both', 'expand' => true)
    
    @logText = logText
  end
 
 
  def createFigureList(parent)

    listFrame = TkFrame.new(parent) { background 'WhiteSmoke' }
    listBox = TkListbox.new(listFrame) {
      selectmode 'single'
      background 'white'
      borderwidth 0
      height 6
      font $figures_font
    }
    scrollBar = TkScrollbar.new(listFrame) { command proc { |*args| listBox.yview(*args) } }
    listBox.yscrollcommand(proc { |first, last| scrollBar.set(first, last) })
    
    listBox.bind('ButtonRelease-1') { figureSelected }
 
    spacer = TkFrame.new(listFrame) { background 'WhiteSmoke' }
    spacer.pack('side' => 'left', 'padx' => 4) 
    
    listBox.pack('side' => 'left', 'fill' => 'both', 'expand' => true, 'pady' => 2)
    scrollBar.pack('side' => 'right', 'fill' => 'y', 'pady' => 3)
    
    listFrame.pack('side' => 'left', 'fill' => 'both', 'expand' => true)
 
    @listBox = listBox
  end
  
  
  def createEvalField(parent)
  
    evalFrame = TkFrame.new(parent, 'background' => 'WhiteSmoke') do
    	pack('side' => 'bottom', 'fill' => 'x', 'pady' => 4)
    end
  
    evalLabel = TkLabel.new(evalFrame, 'background' => 'WhiteSmoke') do
      text ' eval'
      font 'courier 12'
    	pack('side' => 'left')
    end
  
    evalEntry = TkEntry.new(evalFrame) do
      borderwidth 0
    	pack('side' => 'left', 'fill' => 'x', 'expand' => true)
    end
    
    TkLabel.new(evalFrame, 'background' => 'WhiteSmoke') do
      text '  '
      font 'courier 12'
    	pack('side' => 'right')
    end    
    
    evalEntry.bind('Key-Return', proc { eval })
    
    @evalEntry = evalEntry

  end
  
  
  def set_working_dir(filename)
    if $change_working_directory && filename[0..0] == '/'
      
      parts = filename.split('/')
      if parts[-1].length < 2 || parts[-1][-2..-1] != "rb"
        append_to_log "ERROR: filename must have extension 'rb'   instead has <" + parts[-1][-2..-1] + ">"
        exit
      end
      dir = ""
      parts[0..-2].each {|part| dir << '/' + part unless part.length == 0 }
      append_to_log " "
      append_to_log filename
      
      append_to_log "changing working directory to " + dir
      Dir.chdir(dir) # change current working directory
    end
  end

 
  def initialize(filename,opt1,opt2)
      
    # set the standard defaults
    $pdf_viewer = "xpdf -remote tioga"
    $geometry = '600x250+700+50'
    $background = 'WhiteSmoke'
    $mac_command_key = false
    $change_working_directory = true
    $log_font = 'system 12'
    $figures_font = 'system 12'
    
    tiogainit_name = ENV['HOME'] + '/.tiogainit'
    file = File.open(tiogainit_name, 'r')
    if (file != nil)
    
      $filename = filename
      $opt1 = opt1
      $opt2 = opt2
      
      file.close
      load(tiogainit_name)
    
      filename = $filename
      opt1 = $opt1
      opt2 = $opt2
    
      $filename = nil
      $opt1 = nil
      $opt2 = nil
      
    end
    
    set_working_dir(filename) unless filename == nil

    @tioga_filename = filename
    @pdf_name = nil
    @have_loaded = false
    
    @history = [ ]
    resetHistory
    
    if (filename != nil)
      
      @batch_mode = true
    
      if opt1 == '-l'
        loadfile(filename)
        fm.figure_names.each_with_index { |name,i| puts sprintf("%3i    %s\n",i,name) }
        return
      elsif opt1 != nil && (opt1.kind_of?String) && (/^\d+$/ === opt1[1..-1])
        loadfile(filename)
        view_pdf(require_pdf(opt1[1..-1].to_i))
        return
      elsif (opt1 == '-s' || opt1 == '-m') && opt2 != nil
        opt2 = opt2.to_i if (/^\d+$/ === opt2)
        loadfile(filename)
        view_pdf(require_pdf(opt2)) if opt1 == '-s'
        return
      elsif opt1 == '-p'
        loadfile(filename)
        puts fm.num_figures
        if fm.num_figures == 1
          view_pdf(require_pdf(0))
        else
          make_portfolio(true) # make and show
        end
        return
      elsif opt1 == '-a'
        loadfile(filename)
        make_all_pdfs
        return
      elsif opt1 != nil || filename == '-help'
        puts 'Sorry: ' + opt1 + ' is not a recognized option.' unless opt1 == '-help' || filename == '-help'
        puts "\nCommand line arguments must always start with the name of the tioga figures .rb file."
        puts "The rest of the command line should be one of the following cases."
        puts ''
        puts '    -l          list the defined figures by number and name'
        puts '    -<num>      show a figure PDF: <num> is the figure number (0 for the first figure)'
        puts '    -s <fig>    show a figure PDF: <fig> is the figure name or number'
        puts '    -p          show a portfolio of all the figures'
        puts '    -m <fig>    make a figure PDF without showing it'
        puts '    -a          make all the figure PDFs without showing them'
        puts "\nFor more information, visit http://theory.kitp.ucsb.edu/~paxton/tioga.html"
        puts ''
        return
      end
    
    end
     
    @batch_mode = false
    
    @accel_key = ($mac_command_key)? 'Cmd' : 'Ctrl'
    @bind_key = ($mac_command_key)? 'Command' : 'Control'

    require 'tk'
   
    @root = TkRoot.new { 
      geometry $geometry
      background $background
      pady 2
      }
 
    createMenubar(@root)
    contentFrame = TkFrame.new(@root) { background 'WhiteSmoke' }
    createFigureList(contentFrame)
    createLogText(contentFrame)
    contentFrame.pack('side' => 'top', 'fill' => 'both', 'expand' => true)
    createEvalField(@root)
    @root.bind('Key-Up', proc { prev_in_list })
    @root.bind('Key-Down', proc { next_in_list })
    @root.bind('Key-Left', proc { back })
    @root.bind('Key-Right', proc { forward })
    
    loadfile(filename) unless filename == nil
    Tk.mainloop(false)
    
  end
  
end

TiogaUI.new(ARGV[0],ARGV[1],ARGV[2])
