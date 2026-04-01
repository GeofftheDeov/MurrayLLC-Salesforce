Account acc = [SELECT Id, Name, Industry, Website, Phone, BillingStreet, BillingCity, BillingState, RecordTypeId, RecordType.Name FROM Account LIMIT 1];

Map<String, Object> accountMap = new Map<String, Object>();
accountMap.put('sfID', acc.Id);
accountMap.put('name', acc.Name);
accountMap.put('industry', acc.Industry);
accountMap.put('website', acc.Website);
accountMap.put('phone', acc.Phone);

String address = '';
if (String.isNotBlank((String)acc.get('BillingStreet'))) address += (String)acc.get('BillingStreet');
if (String.isNotBlank((String)acc.get('BillingCity'))) address += (String.isNotBlank(address) ? ', ' : '') + (String)acc.get('BillingCity');
if (String.isNotBlank((String)acc.get('BillingState'))) address += (String.isNotBlank(address) ? ', ' : '') + (String)acc.get('BillingState');
accountMap.put('address', address);

accountMap.put('sfRecordTypeID', acc.get('RecordTypeId'));
SObject recordType = acc.getSObject('RecordType');
accountMap.put('sfRecordTypeName', recordType != null ? recordType.get('Name') : null);

List<Map<String, Object>> accountsData = new List<Map<String, Object>>{accountMap};
Map<String, Object> requestBody = new Map<String, Object>{'accounts' => accountsData};

HttpRequest req = new HttpRequest();
req.setEndpoint('https://api.goeffthedeov.net/api/accounts/sync');
req.setMethod('POST');
req.setHeader('Content-Type', 'application/json');
req.setHeader('x-api-key', 'yeos-I-am-authorized!');
req.setBody(JSON.serialize(requestBody));

Http http = new Http();
HttpResponse res = http.send(req);

System.debug('STATUS CODE: ' + res.getStatusCode());
System.debug('RESPONSE BODY: ' + res.getBody());
