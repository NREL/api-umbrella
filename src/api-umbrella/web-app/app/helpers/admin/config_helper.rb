module Admin::ConfigHelper
  def yaml_diff(before, after)
    before_dump = ""
    if(before.present?)
      before_dump = Psych.dump(before)
    end

    after_dump = ""
    if(after.present?)
      after_dump = Psych.dump(after)
    end

    Diffy::Diff.new(before_dump, after_dump).to_s(:html).html_safe
  end

  def import_yaml_diff(before, after)
    yaml_diff(simplify_import_data(before), simplify_import_data(after))
  end
end
