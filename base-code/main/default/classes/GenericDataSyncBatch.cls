/**
 * @description Schedulable batch job to sync dynamic generic Salesforce objects to Web App
 */
public class GenericDataSyncBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Schedulable, Database.Stateful {
    
    // Named Credential endpoint
    private static final String NAMED_CREDENTIAL = 'callout:Personal_Web_App/sync/salesforce';
    private static final Integer BATCH_SIZE = 200;
    
    // Current Configuration being synced
    private Web_App_Sync_Config__mdt currentConfig;
    
    // Queue of configs to run afterwards
    private List<Web_App_Sync_Config__mdt> remainingConfigs;

    /**
     * Default Constructor - Initializes by getting all active configs and starting with the first
     */
    public GenericDataSyncBatch() {
        this.remainingConfigs = [
            SELECT Id, DeveloperName, Object_API_Name__c, Fields_to_Sync__c, Order__c 
            FROM Web_App_Sync_Config__mdt 
            WHERE Active__c = true 
            ORDER BY Order__c ASC
        ];
        
        if (!this.remainingConfigs.isEmpty()) {
            this.currentConfig = this.remainingConfigs.remove(0);
        }
    }

    /**
     * Constructor for chained execution
     */
    public GenericDataSyncBatch(Web_App_Sync_Config__mdt current, List<Web_App_Sync_Config__mdt> remaining) {
        this.currentConfig = current;
        this.remainingConfigs = remaining;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        if (currentConfig == null) {
            System.debug('GenericDataSyncBatch: No configuration to run.');
            return Database.getQueryLocator('SELECT Id FROM Account LIMIT 0');
        }
        
        System.debug('GenericDataSyncBatch: Starting batch job for ' + currentConfig.Object_API_Name__c);
        
        String fields = currentConfig.Fields_to_Sync__c;
        if (String.isBlank(fields)) fields = 'Id';
        
        String query = 'SELECT ' + fields + ' FROM ' + currentConfig.Object_API_Name__c + ' WHERE IsDeleted = false';
        
        return Database.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        if (currentConfig == null || scope.isEmpty()) return;
        
        System.debug('GenericDataSyncBatch: Processing ' + scope.size() + ' records for ' + currentConfig.Object_API_Name__c);
        
        try {
            List<Map<String, Object>> recordsData = new List<Map<String, Object>>();
            
            Set<String> fieldsSet = new Set<String>();
            if (currentConfig.Fields_to_Sync__c != null) {
                for (String f : currentConfig.Fields_to_Sync__c.split(',')) {
                    fieldsSet.add(f.trim().toLowerCase());
                }
            }
            
            for (SObject obj : scope) {
                Map<String, Object> recordMap = new Map<String, Object>();
                Map<String, Object> popFields = obj.getPopulatedFieldsAsMap();
                for (String fieldKey : popFields.keySet()) {
                    if (fieldsSet.contains(fieldKey.toLowerCase()) || fieldKey.equalsIgnoreCase('Id')) {
                        recordMap.put(fieldKey, popFields.get(fieldKey));
                    }
                }
                recordsData.add(recordMap);
            }
            
            Map<String, Object> requestBody = new Map<String, Object>();
            requestBody.put('object', currentConfig.Object_API_Name__c);
            requestBody.put('records', recordsData);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(NAMED_CREDENTIAL);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(requestBody));
            req.setTimeout(120000);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                System.debug('GenericDataSyncBatch: Successfully synced ' + scope.size() + ' records');
            } else {
                System.debug('GenericDataSyncBatch: Error Http ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('GenericDataSyncBatch: Exception - ' + e.getMessage() + ' - ' + e.getStackTraceString());
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        System.debug('GenericDataSyncBatch: Batch job completed for ' + (currentConfig != null ? currentConfig.Object_API_Name__c : 'N/A'));
        
        if (remainingConfigs != null && !remainingConfigs.isEmpty()) {
            Web_App_Sync_Config__mdt nextConfig = remainingConfigs.remove(0);
            System.debug('GenericDataSyncBatch: Chaining next batch for: ' + nextConfig.Object_API_Name__c);
            
            if (!Test.isRunningTest()) {
                Database.executeBatch(new GenericDataSyncBatch(nextConfig, remainingConfigs), BATCH_SIZE);
            }
        } else {
            System.debug('GenericDataSyncBatch: All configs synced.');
        }
    }
    
    public void execute(SchedulableContext sc) {
        System.debug('GenericDataSyncBatch: Executing scheduled batch');
        Database.executeBatch(new GenericDataSyncBatch(), BATCH_SIZE);
    }
}
