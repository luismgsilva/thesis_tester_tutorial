require 'json'
require 'terminal-table'

def create_table(config, data, opts, filter)
  config = JSON.pretty_generate config
  config = JSON.parse config
  _, tmp = config.first
  hashes = tmp["files"].keys

  table = Terminal::Table.new do |t|
     
    header = ["", "D(PASS)", "D(FAIL)", "D(NEW)", "D(REM)",
              "PASS", "FAIL", "XFAIL", "XPASS", "UNRESOLVED", "UNSUPPORTED",
              "PASS", "FAIL", "XFAIL", "XPASS", "UNRESOLVED", "UNSUPPORTED"
    ]

    t.headings = ["", { value: "Delta", colspan: 4, alignment: :center },
                  { value: hashes[0], colspan: 6, alignment: :center },
                    { value: hashes[1], colspan: 6, alignment: :center }]

    t.add_row header
    t.add_separator
    config.each_pair do |task, json|
      results1 = json["files"][hashes[0]]
      results2 = json["files"][hashes[1]]

#      tmp = []
      verbose_output = []
      row = [task]
      row[5] = results1["PASS"] || 0
      row[6] = results1["FAIL"] || 0
      row[7] = results1["XFAIL"] || 0
      row[8] = results1["XPASS"] || 0
      row[9] = results1["UNRESOLVED"] || 0
      row[10] = results1["UNSUPPORTED"] || 0
      row[11] = results2["PASS"] || 0
      row[12] = results2["FAIL"] || 0
      row[13] = results2["XFAIL"] || 0
      row[14] = results2["XPASS"] || 0
      row[15] = results2["UNRESOLVED"] || 0
      row[16] = results2["UNSUPPORTED"] || 0
  
      row[1] = json["results_delta"]["new_pass"]
      row[2] = json["results_delta"]["new_fail"]
      row[3] = json["results_delta"]["add_test"]
      row[4] = json["results_delta"]["rem_test"]
      t.add_row(row)


      mapping = {
        "npass" => "new_pass",
        "nfail" => "new_fail",
        "atest" => "add_test",
        "rtest" => "rem_test",
        "passfail" => "new_fail",
        "failpass" => "new_pass"
      }

      @filter ||= []
      verbose = []

      if @filter.empty?
        verbose = ["new_pass", "new_fail", "add_test", "rem_test"]
      else
        verbose = @filter.map { |f| mapping[f] }.compact
      end

      verbose.each do |type|
        next if json["changes"][type].values.empty?

        verbose_output << ("  " + type.gsub("_", " ").capitalize)

        json["changes"][type].each_pair do |t, v|
          #next if !@filter.empty? && !(%w[failpass passfail].include?(@filter.first))
          if v["before"] == "PASS" and v["after"] == "FAIL" and (%w[passfail] & @filter).any?
            verbose_output << "    (#{v["before"]}) => (#{v["after"]}) : #{t}"
          elsif v["before"] == "FAIL" and v["after"] == "PASS" and (%w[failpass] & @filter).any?
            verbose_output << "    (#{v["before"]}) => (#{v["after"]}) : #{t}"
          elsif v["before"] != "PASS" and v["after"] == "PASS" and (%w[npass] & @filter).any?
            verbose_output << "    (#{v["before"]}) => (#{v["after"]}) : #{t}"
          elsif v["before"] != "FAIL" and v["after"] == "FAIL" and (%w[nfail] & @filter).any?
            verbose_output << "    (#{v["before"]}) => (#{v["after"]}) : #{t}"
          elsif !(%w[failpass passfail] & @filter).any?
            verbose_output << "    (#{v["before"]}) => (#{v["after"]}) : #{t}"
          end
        end
        verbose_output << ""
      end
      data[task] = verbose_output

    end
  end
  return table
end

def print_compare(data)
  data.keys.each do |k|
    next if data[k].empty?
    v = data[k]
    puts "=== #{k} ==="
    puts v.join("\n")
    puts ""
  end
end

def generate_compare_html(data)
  html_content = []
  data.keys.each do |k|
    next if data[k].empty?
    v = data[k]
    html_content.push("<h2>#{k}</h2>")
    html_content.push("<p>#{v.join('</p><p>')}</p>")
  end
  html_content
end

def convert_table_html(table, html_content=nil)
  html_table = <<~HTML
    <style>
      table {
        border-collapse: collapse;
        width: 100%;
       font-family: Arial, sans-serif;
      }

      th, td {
        border: 1px solid #ddd;
        padding: 8px;
        text-align: center;
      }

      th {
        background-color: #f2f2f2;
      }

      tr:nth-child(even) {
        background-color: #f2f2f2;
      }
    </style>
    <table>
      <tr>
        #{table.headings.map do |heading|
          heading.cells.map do |cell|
            colspan = cell.colspan || 1
            "<th colspan=#{colspan}>#{cell.value}</th>"
          end
        end.join}
      </tr>
      #{table.rows.map do |row|
        "<tr>" + row.cells.map { |cell| "<td colspan=#{cell.colspan}>#{cell.value}</td>" }.join + "</tr>"
      end.join}
    </table>
    #{if html_content
      "<body>" + html_content.join("\n") + "</body>"
    end}
  HTML
  return html_table
end
