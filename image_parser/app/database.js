// Imports the Google Cloud client library
const Bigtable = require('@google-cloud/bigtable');

exports.saveToBigtable = (instanceId, tableId, rowKey, itemObject, itemLabels, callback) => {
    console.log('Attempting to create a bigtable client');
    // Creates a Bigtable client
    const bigtable = Bigtable();

    console.log(`Attempting to connect to the bt instance with ID: ${instanceId}`);
    // Connect to an existing instance
    const instance = bigtable.instance(instanceId);

    console.log(`Attempting to instantiate the bt table with ID: ${tableId}`);
    // Connect to an existing table
    const table = instance.table(tableId);

    console.log(`Checking for the existence of table ID: ${tableId}`);
    table.exists(function (err, tableExists) {
        if (!tableExists) {
            return callback(new Error(`You first need to create the table with a table ID of: ${tableId}`))
        }

        console.log(`Checking for the existence of table ID: ${tableId}`);
        const rowToInsert = {
            key: rowKey,
            data: {
                'item': {
                    'labels_as_json_string': {
                        value: JSON.stringify(itemLabels),
                    }
                },
                'seller': {},
                'buyer': {}
            },
        }

        if (itemObject.option.toLowerCase() == 'sell') {
            rowToInsert.data.seller[itemObject.userName] = {
                value: JSON.stringify(itemObject),
            }

        } else {
            rowToInsert.data.buyer[itemObject.userName] = {
                value: JSON.stringify(itemObject),
            }
        }
        console.log(`Attempting to insert the row to BT with rowkey: ${rowKey}`);
        table.insert(rowToInsert, function(err) {
            if (err) {
                return callback(err);
            }
            else {
                return callback();
            }
        });

    });

}
