// Execute the AccountSyncBatch
AccountSyncBatch batch = new AccountSyncBatch();
Database.executeBatch(batch, 200);
System.debug('Batch job queued successfully');
