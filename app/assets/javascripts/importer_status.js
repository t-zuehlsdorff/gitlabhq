/* eslint-disable func-names, space-before-function-paren, wrap-iife, camelcase, no-var, one-var, one-var-declaration-per-line, prefer-template, quotes, object-shorthand, comma-dangle, no-unused-vars, prefer-arrow-callback, no-else-return, vars-on-top, no-new, max-len */

(function() {
  window.ImporterStatus = (function() {
    function ImporterStatus(jobs_url, import_url) {
      this.jobs_url = jobs_url;
      this.import_url = import_url;
      this.initStatusPage();
      this.setAutoUpdate();
    }

    ImporterStatus.prototype.initStatusPage = function() {
      $('.js-add-to-import').off('click').on('click', (function(_this) {
        return function(e) {
          var $btn, $namespace_input, $target_field, $tr, id, target_namespace, newName;
          $btn = $(e.currentTarget);
          $tr = $btn.closest('tr');
          $target_field = $tr.find('.import-target');
          $namespace_input = $target_field.find('.js-select-namespace option:selected');
          id = $tr.attr('id').replace('repo_', '');
          target_namespace = null;
          newName = null;
          if ($namespace_input.length > 0) {
            target_namespace = $namespace_input[0].innerHTML;
            newName = $target_field.find('#path').prop('value');
            $target_field.empty().append(target_namespace + "/" + newName);
          }
          $btn.disable().addClass('is-loading');
          return $.post(_this.import_url, {
            repo_id: id,
            target_namespace: target_namespace,
            new_name: newName
          }, {
            dataType: 'script'
          });
        };
      })(this));
      return $('.js-import-all').off('click').on('click', function(e) {
        var $btn;
        $btn = $(this);
        $btn.disable().addClass('is-loading');
        return $('.js-add-to-import').each(function() {
          return $(this).trigger('click');
        });
      });
    };

    ImporterStatus.prototype.setAutoUpdate = function() {
      return setInterval(((function(_this) {
        return function() {
          return $.get(_this.jobs_url, function(data) {
            return $.each(data, function(i, job) {
              var job_item, status_field;
              job_item = $("#project_" + job.id);
              status_field = job_item.find(".job-status");
              if (job.import_status === 'finished') {
                job_item.removeClass("active").addClass("success");
                return status_field.html('<span><i class="fa fa-check"></i> done</span>');
              } else if (job.import_status === 'scheduled') {
                return status_field.html("<i class='fa fa-spinner fa-spin'></i> scheduled");
              } else if (job.import_status === 'started') {
                return status_field.html("<i class='fa fa-spinner fa-spin'></i> started");
              } else {
                return status_field.html(job.import_status);
              }
            });
          });
        };
      })(this)), 4000);
    };

    return ImporterStatus;
  })();

  $(function() {
    if ($('.js-importer-status').length) {
      var jobsImportPath = $('.js-importer-status').data('jobs-import-path');
      var importPath = $('.js-importer-status').data('import-path');

      new window.ImporterStatus(jobsImportPath, importPath);
    }
  });
}).call(window);
