{% test analysis_not_before_collection(model, column_name, collected_column) %}

-- Business rule: a laboratory cannot analyze a sample before it was collected.
-- Rows without an analysis date (field measurements) are ignored.
-- Returning 0 rows = pass.

select *
from {{ model }}
where {{ column_name }} is not null
  and {{ column_name }} < {{ collected_column }}

{% endtest %}