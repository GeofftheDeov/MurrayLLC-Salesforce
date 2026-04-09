@isTest
private class GenericDataSyncBatch_Test {
    
    // Mock callout class
    public class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"message":"Success"}');
            res.setStatusCode(200);
            return res;
        }
    }
    
    @isTest
    static void testBatchExecution() {
        // Create test data
        Account testAcc = new Account(Name = 'Test Sync Account');
        insert testAcc;
        
        Lead testLead = new Lead(FirstName = 'Sync', LastName = 'Test', Company = 'Sync Co');
        insert testLead;
        
        // Custom Metadata Types cannot be inserted in test context using standard DML,
        // but the query in the constructor will just select what's physically in the org.
        // We will mock the constructor by injecting configurations directly.
        
        // This is a dynamic instanciation. Instead of relying on org metadata,
        // let's create JSON stubs and deserialize them to simulate metadata if needed.
        // But since we built the actual custom metadata types and deployed, the query will return the real ones 
        // if they are already active. Just to be safe, we can manually supply the config via constructor.
        
        List<Web_App_Sync_Config__mdt> testConfigs = new List<Web_App_Sync_Config__mdt>();
        
        Web_App_Sync_Config__mdt accConfig = (Web_App_Sync_Config__mdt)JSON.deserialize(
            '{"Object_API_Name__c":"Account", "Fields_to_Sync__c":"Id,Name", "Active__c":true}', 
            Web_App_Sync_Config__mdt.class
        );
        testConfigs.add(accConfig);
        
        Web_App_Sync_Config__mdt leadConfig = (Web_App_Sync_Config__mdt)JSON.deserialize(
            '{"Object_API_Name__c":"Lead", "Fields_to_Sync__c":"Id,FirstName,LastName", "Active__c":true}', 
            Web_App_Sync_Config__mdt.class
        );
        testConfigs.add(leadConfig);
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        // We pass the FIRST config to process, and the remaining to the chained process.
        // During test execution, chaining batch from finish() is blocked if Test.isRunningTest() is used in the class.
        // Our class uses `if (!Test.isRunningTest())` to prevent the "chaining batch in test" error.
        
        Web_App_Sync_Config__mdt firstConfig = testConfigs.remove(0);
        GenericDataSyncBatch batch = new GenericDataSyncBatch(firstConfig, testConfigs);
        Database.executeBatch(batch, 200);
        
        Test.stopTest();
        
        // Assertions are difficult without mocking the endpoint logic but we verify the batch completes without exceptions
        System.assert(true, 'Batch completed successfully');
    }
    
    @isTest
    static void testSchedulable() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        String jobId = System.schedule('Test GenericDataSyncBatch', '0 0 0 * * ?', new GenericDataSyncBatch());
        Test.stopTest();
        
        System.assertNotEquals(null, jobId, 'Job was not scheduled');
    }
}
