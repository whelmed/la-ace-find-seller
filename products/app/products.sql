SELECT * FROM (
  
  SELECT 
    s.name, 
    s.cell.timestamp, 
    JSON_EXTRACT_SCALAR(s.cell.value, '$.notes') as note, 
    JSON_EXTRACT_SCALAR(s.cell.value, '$.price') as price,
    JSON_EXTRACT_SCALAR(s.cell.value, '$.fileName') as filename,
    'seller' as option
  FROM `app_dataset_dev.items`,  UNNEST(seller.column) as s 
  ORDER BY s.cell.timestamp DESC LIMIT 5
)
UNION ALL
SELECT * FROM (
  
  SELECT 
    b.name, 
    b.cell.timestamp, 
    JSON_EXTRACT_SCALAR(b.cell.value, '$.notes') as note, 
    JSON_EXTRACT_SCALAR(b.cell.value, '$.price') as price,
    JSON_EXTRACT_SCALAR(b.cell.value, '$.fileName') as filename,
    'buyer' as option
  FROM `app_dataset_dev.items`,  UNNEST(buyer.column) as b
  ORDER BY b.cell.timestamp DESC LIMIT 5
)