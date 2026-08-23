def reconcile($old; $new; $actual):
  if (($old | type) == "object"
      and ($new | type) == "object"
      and ($actual | type) == "object") then
    reduce ((($old | keys_unsorted) + ($new | keys_unsorted)) | unique[]) as $key
      ($actual;
        if ($new | has($key) | not) then
          if (($actual | has($key)) and $actual[$key] == $old[$key]) then
            del(.[$key])
          else
            .
          end
        elif ($old | has($key) | not) then
          if (($new[$key] | type) == "object"
              and ($actual | has($key))
              and ($actual[$key] | type) == "object") then
            .[$key] = reconcile({}; $new[$key]; $actual[$key])
          else
            .[$key] = $new[$key]
          end
        elif $new[$key] == $old[$key] then
          .
        elif (($old[$key] | type) == "object"
              and ($new[$key] | type) == "object"
              and ($actual | has($key))
              and ($actual[$key] | type) == "object") then
          .[$key] = reconcile($old[$key]; $new[$key]; $actual[$key])
        else
          .[$key] = $new[$key]
        end)
  elif $new == $old then
    $actual
  else
    $new
  end;

reconcile($old[0]; $new[0]; $actual[0])
