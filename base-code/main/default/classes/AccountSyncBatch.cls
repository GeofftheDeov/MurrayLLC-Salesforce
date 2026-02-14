/**
 * @description Schedulable batch job to sync Salesforce Account records to MongoDB
 * @author Geoff Murray
 */
public class AccountSyncBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Schedulable, Database.Stateful {
    
    // Named Credential name
    private static final String NAMED_CREDENTIAL = 'callout:MongoDB_API';
    
    // Batch size
    private static final Integer BATCH_SIZE = 200;
    
    /**
     * Start method - Query all Account records
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('AccountSyncBatch: Starting batch job');
        String query = 'SELECT Id, Name, Industry, Website, Phone, BillingStreet, BillingCity, BillingState, RecordTypeId, RecordType.Name FROM Account WHERE IsDeleted = false';
        return Database.getQueryLocator(query);
    }
    
    /**
     * Execute method - Process batches and sync to MongoDB
     */
    public void execute(Database.BatchableContext bc, List<Account> scope) {
        System.debug('AccountSyncBatch: Processing ' + scope.size() + ' accounts');
        
        try {
            // Build JSON payload
            List<Map<String, Object>> accountsData = new List<Map<String, Object>>();
            
            for (Account acc : scope) {
                Map<String, Object> accountMap = new Map<String, Object>();
                accountMap.put('sfID', acc.get('Id'));
                accountMap.put('name', acc.get('Name'));
                accountMap.put('industry', acc.get('Industry'));
                accountMap.put('website', acc.get('Website'));
                accountMap.put('phone', acc.get('Phone'));
                
                // Build address string
                String address = '';
                if (String.isNotBlank((String)acc.get('BillingStreet'))) {
                    address += (String)acc.get('BillingStreet');
                }
                if (String.isNotBlank((String)acc.get('BillingCity'))) {
                    address += (String.isNotBlank(address) ? ', ' : '') + (String)acc.get('BillingCity');
                }
                if (String.isNotBlank((String)acc.get('BillingState'))) {
                    address += (String.isNotBlank(address) ? ', ' : '') + (String)acc.get('BillingState');
                }
                if (String.isNotBlank((String)acc.get('BillingPostalCode'))) {
                    address += (String.isNotBlank(address) ? ' ' : '') + (String)acc.get('BillingPostalCode');
                }
                if (String.isNotBlank((String)acc.get('BillingCountry'))) {
                    address += (String.isNotBlank(address) ? ', ' : '') + (String)acc.get('BillingCountry');
                }
                accountMap.put('address', address);
                
                accountMap.put('sfRecordTypeID', acc.get('RecordTypeId'));
                
                // Handle RecordType relationship safely
                SObject recordType = acc.getSObject('RecordType');
                accountMap.put('sfRecordTypeName', recordType != null ? recordType.get('Name') : null);
                
                accountsData.add(accountMap);
            }
            
            // Create request payload
            Map<String, Object> requestBody = new Map<String, Object>();
            requestBody.put('accounts', accountsData);
            
            // Make HTTP callout
            HttpRequest req = new HttpRequest();
            req.setEndpoint(NAMED_CREDENTIAL);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(requestBody));
            req.setTimeout(120000); // 2 minute timeout
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                System.debug('AccountSyncBatch: Successfully synced ' + scope.size() + ' accounts');
                System.debug('Response: ' + res.getBody());
            } else {
                System.debug('AccountSyncBatch: Error syncing accounts. Status: ' + res.getStatusCode());
                System.debug('Response: ' + res.getBody());
            }
            
        } catch (Exception e) {
            System.debug('AccountSyncBatch: Exception - ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
    }
    
    /**
     * Finish method - Log completion
     */
    public void finish(Database.BatchableContext bc) {
        System.debug('AccountSyncBatch: Batch job completed');
        
        // Query the AsyncApexJob to get batch statistics
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors, JobItemsProcessed,
                   TotalJobItems, CreatedDate, CompletedDate
            FROM AsyncApexJob
            WHERE Id = :bc.getJobId()
        ];
        
        System.debug('Batch Status: ' + job.Status);
        System.debug('Total Batches: ' + job.TotalJobItems);
        System.debug('Batches Processed: ' + job.JobItemsProcessed);
        System.debug('Errors: ' + job.NumberOfErrors);
    }
    
    /**
     * Schedulable execute method - Schedule the batch job
     * Schedule using: System.schedule('Account Sync to MongoDB', '0 0 2 * * ?', new AccountSyncBatch());
     */
    public void execute(SchedulableContext sc) {
        System.debug('AccountSyncBatch: Executing scheduled batch');
        Database.executeBatch(new AccountSyncBatch(), BATCH_SIZE);
    }
}
