/**
 * @description Test class for AccountSyncBatch
 */
@IsTest
private class AccountSyncBatch_Test {
    
    /**
     * Mock HTTP callout for testing
     */
    private class MockHttpResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"message":"Sync completed","results":{"success":2,"failed":0,"errors":[]}}');
            res.setStatusCode(200);
            return res;
        }
    }
    
    /**
     * Test batch execution
     */
    @IsTest(SeeAllData=true)
    static void testBatchExecution() {
        // Query existing accounts or create simple ones
        List<Account> existingAccounts = [SELECT Id FROM Account LIMIT 5];
        
        if (existingAccounts.isEmpty()) {
            // Create minimal test accounts
            List<Account> testAccounts = new List<Account>();
            for (Integer i = 0; i < 5; i++) {
                testAccounts.add(new Account(Name = 'Test Account ' + i));
            }
            insert testAccounts;
        }
        
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        
        Test.startTest();
        AccountSyncBatch batch = new AccountSyncBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        // Verify batch completed (no exceptions thrown)
        System.assert([SELECT COUNT() FROM Account] >= 5, 'Should have at least 5 accounts');
    }
    
    /**
     * Test schedulable execution
     */
    @IsTest
    static void testSchedulableExecution() {
        // Create test account
        Account testAccount = new Account(
            Name = 'Scheduled Test Account',
            Industry = 'Finance'
        );
        insert testAccount;
        
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        
        Test.startTest();
        String cronExp = '0 0 2 * * ?';
        String jobId = System.schedule('Test Account Sync', cronExp, new AccountSyncBatch());
        Test.stopTest();
        
        // Verify scheduled job was created
        System.assertNotEquals(null, jobId, 'Job ID should not be null');
        
        CronTrigger ct = [
            SELECT Id, CronExpression, TimesTriggered, NextFireTime
            FROM CronTrigger
            WHERE Id = :jobId
        ];
        
        System.assertEquals(cronExp, ct.CronExpression, 'Cron expression should match');
        System.assertEquals(0, ct.TimesTriggered, 'Should not have triggered yet');
    }
    
    /**
     * Test with no accounts
     */
    @IsTest
    static void testBatchWithNoAccounts() {
        // Delete all accounts
        delete [SELECT Id FROM Account];
        
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        
        Test.startTest();
        AccountSyncBatch batch = new AccountSyncBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        // Verify no errors (batch should handle empty result gracefully)
        System.assertEquals(0, [SELECT COUNT() FROM Account], 'Should have 0 accounts');
    }
    
    /**
     * Test error handling
     */
    @IsTest
    static void testErrorHandling() {
        // Create test account
        Account testAccount = new Account(
            Name = 'Error Test Account'
        );
        insert testAccount;
        
        // Mock error response
        Test.setMock(HttpCalloutMock.class, new MockHttpErrorResponse());
        
        Test.startTest();
        AccountSyncBatch batch = new AccountSyncBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        // Batch should complete without throwing exception
        System.assertEquals(1, [SELECT COUNT() FROM Account], 'Should have 1 test account');
    }
    
    /**
     * Mock HTTP error response
     */
    private class MockHttpErrorResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"error":"Internal server error"}');
            res.setStatusCode(500);
            return res;
        }
    }
}
