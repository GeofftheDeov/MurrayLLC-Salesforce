Account acc = [SELECT Id, Name, Industry, Website, Phone, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, RecordTypeId, RecordType.Name FROM Account LIMIT 1];

Map<String, Object> accountMap = new Map<String, Object>();
accountMap.put('sfID', acc.Id);
accountMap.put('name', acc.Name);

List<Map<String, Object>> accountsData = new List<Map<String, Object>>{accountMap};
Map<String, Object> requestBody = new Map<String, Object>{'accounts' => accountsData};

HttpRequest req = new HttpRequest();
req.setEndpoint('callout:Personal_Web_App');
req.setMethod('POST');
req.setHeader('Content-Type', 'application/json');
req.setBody(JSON.serialize(requestBody));

Http http = new Http();
try {
    HttpResponse res = http.send(req);
    System.debug('STATUS CODE: ' + res.getStatusCode());
    System.debug('RESPONSE BODY: ' + res.getBody());
} catch (Exception e) {
    System.debug('EXCEPTION: ' + e.getMessage());
}
