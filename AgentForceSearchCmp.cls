/**
 * @description Invocable Apex class to search for metadata components in the current org
 * and identify which of them are missing from a target org, based on a
 * pre-populated custom object report.
 */
public without sharing class AgentForceSearchCmp {

    // Naming and Configuration Constants
    private static final String TOOLING_API_NAMED_CRED = 'Tooling_API_NamedCreds';
    //private static final String REPORT_OBJECT_API_NAME = 'DCOBFusionReportcsv__dll';
    private static final String REPORT_OBJECT_API_NAME = '_TargetOrg__dll';
    private static final String ORG_TYPE_SOURCE = 'Source Org';
    private static final String ORG_TYPE_TARGET = 'Target Org';

    // Metadata Type Constants
    private static final String TYPE_APEX_CLASS = 'ApexClass';
    private static final String TYPE_AURA_COMPONENT = 'LightningComponentBundle';
    private static final String TYPE_VALIDATION_RULE = 'ValidationRule';
    private static final String TYPE_CUSTOM_OBJECT = 'CustomObject';
    private static final String TYPE_CUSTOM_FIELD = 'CustomField';
    private static final String TYPE_EMAIL_TEMPLATE = 'EmailTemplate';
    private static final String TYPE_PERMISSION_SET = 'PermissionSet';
    private static final String TYPE_PAGE_LAYOUT = 'Layout';
    private static final String TYPE_RECORD_TYPE = 'RecordType';
    private static final String TYPE_PROFILE = 'Profile';
    private static final String TYPE_WORKFLOW_RULE = 'WorkflowRule';
    private static final String TYPE_PROCESS_BUILDER = 'ProcessBuilder';
    private static final String TYPE_FLOW = 'Flow';
    //private static final String TYPE_PROFILE = 'Profile';
    //private static final String TYPE_WORKFLOW_COMPONENT = 'CustomField'; //STEP 3
    // Inner classes for Flow Input/Output and data handling
    public class SearchInput {
        @InvocableVariable(label='Search Text' required=true)
        public String searchText;
    }

    public class FlowOutput {
        @InvocableVariable(label='Output')
        public List<PackageXMLWrapper> output;
    }

    // Wrapper for comparing records from the report object
    private class FeatureComponent {
        public String name;

        public FeatureComponent(SObject sObj) {
            this.name = (String) sObj.get('Name__c');
        }

        public Boolean equals(Object obj) {
            if (obj instanceof FeatureComponent) {
                return this.name == ((FeatureComponent)obj).name;
            }
            return false;
        }

        public Integer hashCode() {
            return System.hashCode(this.name);
        }
    }


/**
 * @description Queries Data Cloud Objects to get the list of target org components.
 * @param componentType The metadata type to filter the report by (e.g., 'ApexClass').
 * @return A Set of names for components of that type identified as missing.
 */
private static Set<String> getMissingComponentNamesFromReport(String componentType) {
    String reportObjectName = REPORT_OBJECT_API_NAME;
    String orgSource = ORG_TYPE_SOURCE;
    String orgTarget = ORG_TYPE_TARGET;
    if(componentType =='Layout') {
        componentType = 'PageLayout'; // Adjusting for Layouts as they are stored differently in the report
    }
    String targetQuery = 'SELECT Name__c FROM ' + componentType+reportObjectName;
    List<SObject> targetRecords = Database.query(targetQuery);

    //Set<FeatureComponent> targetSet = createFeatureComponentSet(targetRecords);
    Set<String> missingNames = new Set<String>();
    for (SObject tar : targetRecords) {
        FeatureComponent cmp = new FeatureComponent(tar);
        //if (!targetSet.contains(cmp)) {
            //String cleanedString =  cmp.name.replaceAll('[^a-zA-Z0-9]', '');//Cleaning the name to match the format in the source org
            //system.debug('cleanedString==>'+cleanedString);
            //missingNames.add(cleanedString);
            missingNames.add(cmp.name);
        //}
    }
    system.debug('TargetOrgComponets From Data Cloud==>'+missingNames);
    /**for (SObject src : sourceRecords) {
        FeatureComponent cmp = new FeatureComponent(src);
        if (!targetSet.contains(cmp)) {
            missingNames.add(cmp.name);
        }
    }*/
    return missingNames;
}
@InvocableMethod(label='Search for Missing Components')
public static List<FlowOutput> findMissingComponentsInTarget(List<SearchInput> inputList) {
    //List<FlowOutput> outputs = new List<FlowOutput>();
    //return outputs;
    String keyword = inputList[0].searchText?.trim();
    if (String.isBlank(keyword)) {
        return new List<FlowOutput>();
    }
    
    // 1. Find all components in the current org that match the keyword.
    Map<String, Set<String>> componentsInCurrentOrg = findOrgComponents(keyword);
    system.debug('componentsInCurrentOrg==>'+componentsInCurrentOrg);
    system.debug('componentsInCurrentOrg.keySet()==>'+componentsInCurrentOrg.keySet());
    system.debug('componentsInCurrentOrg.value()==>'+componentsInCurrentOrg.values());
    //system.debug('componentType==>'+componentType);
    List<PackageXMLWrapper> finalMissingList = new List<PackageXMLWrapper>();
    //3. find target org related records from dataCloud
    
    // 2. For each component type, get missing names from the report and find the intersection.
    for (String componentType : componentsInCurrentOrg.keySet()) {
        Set<String> foundInOrg = componentsInCurrentOrg.get(componentType);
        
        // If we didn't find any components of this type in the current org, skip to the next type.
        if (foundInOrg.isEmpty()) {
            continue;
        }
        system.debug('componentType==>'+componentType);
        // Get names of components missing from the target, *filtered by the current component type*.
        //if(componentType!='WorkflowRule'){
            Set<String> missingFromReport = getMissingComponentNamesFromReport(componentType); // will give the all target org components from data cloud
            system.debug('missingFromReport==>'+missingFromReport);
            // 3. Find the intersection: components that are BOTH found in the org AND listed as missing in the report.
            for (String componentName : foundInOrg) { //foundInOrg -- feature based components in current org
            system.debug('componentName==>'+componentName);
            system.debug('missingFromReport==>'+missingFromReport);
                if (!missingFromReport.contains(componentName)) {
                    system.debug('missingFromReportLTGCOMING-1==>'+componentName);
                    system.debug('missingFromReportLTGCOMING-2==>'+missingFromReport);
                    finalMissingList.add(createEntry(componentType, componentName));
                }
            }
    
    }
    system.debug('finalMissingList==>'+finalMissingList);
    FlowOutput flowResult = new FlowOutput();
    flowResult.output = finalMissingList;
    return new List<FlowOutput>{ flowResult };
}

    /**
     * @description Queries various metadata types in the current org.
     * @param keyword The search term to filter components.
     * @return A Map of component type to a Set of component names.
     */
    private static Map<String, Set<String>> findOrgComponents(String keyword) {
        Map<String, Set<String>> results = new Map<String, Set<String>>{
            TYPE_APEX_CLASS => new Set<String>(),
            TYPE_AURA_COMPONENT => new Set<String>(),
            TYPE_VALIDATION_RULE => new Set<String>(),
            TYPE_CUSTOM_OBJECT => new Set<String>(),
            TYPE_CUSTOM_FIELD => new Set<String>(),
            TYPE_EMAIL_TEMPLATE => new Set<String>(),
            TYPE_PERMISSION_SET => new Set<String>(),
            TYPE_PAGE_LAYOUT => new Set<String>(),
            TYPE_RECORD_TYPE => new Set<String>(),
            TYPE_PROFILE => new Set<String>(),
            TYPE_WORKFLOW_RULE => new Set<String>(),
            TYPE_PROCESS_BUILDER => new Set<String>(),
            TYPE_FLOW => new Set<String>()
            //TYPE_WORKFLOW_COMPONENT => new Set<String>() //STEP 2
        };

        String searchPattern = keyword + '%';

        // Native SOQL Queries
        for (ApexClass ac : [SELECT Name FROM ApexClass WHERE Name LIKE :searchPattern LIMIT 1000]) {
            results.get(TYPE_APEX_CLASS).add(ac.Name);
        }
        for (EmailTemplate et : [SELECT Name FROM EmailTemplate WHERE Name LIKE :searchPattern LIMIT 1000]) {
            results.get(TYPE_EMAIL_TEMPLATE).add(et.Name);
        }
        for (PermissionSet ps : [SELECT Name FROM PermissionSet WHERE Name LIKE :searchPattern LIMIT 1000]) {
            results.get(TYPE_PERMISSION_SET).add(ps.Name);
        }
        /**for (Layout ps : [SELECT Name FROM Layout WHERE Name LIKE :searchPattern LIMIT 1000]) {
            results.get(TYPE_PAGE_LAYOUT).add(ps.Name);
        }
        for (LightningComponentBundleinfo LightningCmp : [SELECT DeveloperName FROM LightningComponentBundle WHERE DeveloperName LIKE :searchPattern LIMIT 1000]) {
            results.get(TYPE_AURA_COMPONENT).add(LightningCmp.DeveloperName);
        }*/

        // Tooling API Queries
        results.get(TYPE_VALIDATION_RULE).addAll(queryToolingApi('ValidationRule', 'ValidationName', searchPattern));
        //results.get(TYPE_CUSTOM_OBJECT).addAll(queryToolingApi('CustomObject', 'DeveloperName', searchPattern));
        //results.get(TYPE_CUSTOM_FIELD).addAll(queryToolingApi('CustomField', 'DeveloperName', searchPattern));
        results.get(TYPE_CUSTOM_OBJECT).addAll(getCustomObjectApiNames(searchPattern));
        results.get(TYPE_CUSTOM_FIELD).addAll(getFullCustomFieldNames(searchPattern));
        results.get(TYPE_AURA_COMPONENT).addAll(queryToolingApi('LightningComponentBundle', 'DeveloperName', searchPattern));
        results.get(TYPE_PAGE_LAYOUT).addAll(queryToolingApi('Layout', 'Name', searchPattern));
        results.get(TYPE_RECORD_TYPE).addAll(queryToolingApi('RecordType', 'Name', searchPattern));
        results.get(TYPE_PROFILE).addAll(queryToolingApi('Profile', 'Name', searchPattern));
        results.get(TYPE_WORKFLOW_RULE).addAll(queryToolingApi('WorkflowRule', 'Name', searchPattern));
        results.get(TYPE_PROCESS_BUILDER).addAll(queryToolingApi('ProcessBuilder', 'MasterLabel', searchPattern));
        results.get(TYPE_FLOW).addAll(queryToolingApi('Flow', 'MasterLabel', searchPattern));
        //results.get(TYPE_WORKFLOW_COMPONENT).addAll(queryToolingApi('WorkflowRule', 'Name', searchPattern)); //STEP 1

        return results;
    }

    /**
     * @description Reusable method to query the Tooling API and parse results.
     * @param objectApiName The Tooling API object to query (e.g., 'CustomField').
     * @param fieldApiName The field to select (e.g., 'DeveloperName').
     * @param likePattern The SOQL LIKE pattern for the WHERE clause.
     * @return A List of names found.
     */
    private static List<String> queryToolingApi(String objectApiName, String fieldApiName, String likePattern) {
        List<String> names = new List<String>();
        List<String> CompleteNames = new List<String>();
        try {
            String query = 'SELECT ' + fieldApiName + ' FROM ' + objectApiName + ' WHERE ' + fieldApiName + ' LIKE \'' + String.escapeSingleQuotes(likePattern) + '\' LIMIT 1000';
            /**if(objectApiName == 'Flow'){
                query = 'SELECT MasterLabel, ProcessType FROM Flow WHERE MasterLabel LIKE :searchPattern AND (ProcessType='Flow' OR ProcessType='AutoLaunchedFlow') LIMIT 1000';
            }
            if(objectApiName == 'ProcessBuilder'){
                query = 'SELECT MasterLabel, ProcessType FROM Flow WHERE MasterLabel LIKE :searchPattern AND ProcessType='Workflow' LIMIT 1000';
            }*/
            if(objectApiName == 'Flow'){
                query = 'SELECT MasterLabel, ProcessType FROM Flow WHERE MasterLabel LIKE \'' + String.escapeSingleQuotes(likePattern) + '\' AND (ProcessType = \'Flow\' OR ProcessType = \'AutoLaunchedFlow\') LIMIT 1000';
            }
            if(objectApiName == 'ProcessBuilder'){
                query = 'SELECT MasterLabel, ProcessType FROM Flow WHERE MasterLabel LIKE \'' + String.escapeSingleQuotes(likePattern) + '\' AND ProcessType = \'Workflow\' LIMIT 1000';
            }
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:' + TOOLING_API_NAMED_CRED + '/services/data/v58.0/tooling/query/?q=' + EncodingUtil.urlEncode(query, 'UTF-8'));
            req.setMethod('GET');
            
            HttpResponse res = new Http().send(req);
            system.debug('res.getBody()==>'+res.getBody());
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                system.debug('responseMapToolingAPI==>'+responseMap);
                List<Object> records = (List<Object>) responseMap.get('records');
                system.debug('recordsToolingAPI==>'+records);
                for (Object recordObj : records) {
                    Map<String, Object> record = (Map<String, Object>) recordObj;
                    names.add((String) record.get(fieldApiName));// Cleaning the name to match the format in the source org
                }
                /**for(String name : names) {
                    String cleanedString =  name.replaceAll('[^a-zA-Z0-9]', '');//Cleaning the name to match the format in the source org
                    system.debug('cleanedString==>'+cleanedString);
                    CompleteNames.add(cleanedString);
                }*/
            } else {
                System.debug(System.LoggingLevel.ERROR, 'Tooling API Error for ' + objectApiName + ': ' + res.getBody());
                // Optionally re-throw a custom exception
                // throw new CalloutException(res.getBody());
            }
            system.debug('Tooling API Response for==> ' + objectApiName + ': ' + names);
        } catch (Exception e) {
            System.debug(System.LoggingLevel.ERROR, 'Failed to call Tooling API for ' + objectApiName + '. Details: ' + e.getMessage());
            // Optionally re-throw
        }

        return names;
    }

    /**
     * @description Queries CustomField from Tooling API and returns full names like MyObject__c.MyField__c
     */
    private static List<String> getFullCustomFieldNames(String likePattern) {
        List<Map<String, Object>> rawRecords = new List<Map<String, Object>>();
        List<String> fullNames = new List<String>();

        try {
            String query = 'SELECT DeveloperName, TableEnumOrId FROM CustomField WHERE DeveloperName LIKE \'' + String.escapeSingleQuotes(likePattern) + '\' LIMIT 1000';
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:' + TOOLING_API_NAMED_CRED + '/services/data/v58.0/tooling/query/?q=' + EncodingUtil.urlEncode(query, 'UTF-8'));
            req.setMethod('GET');

            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() == 200) {
                Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> records = (List<Object>) response.get('records');

                Set<String> tableIds = new Set<String>();
                for (Object recObj : records) {
                    Map<String, Object> rec = (Map<String, Object>) recObj;
                    rawRecords.add(rec);
                    tableIds.add((String) rec.get('TableEnumOrId'));
                }

                // Resolve object names using EntityDefinition (handles both standard & custom)
                Map<String, String> idToObjectMap = new Map<String, String>();
                for (EntityDefinition ed : [
                    SELECT DurableId, QualifiedApiName FROM EntityDefinition
                    WHERE DurableId IN :tableIds
                ]) {
                    idToObjectMap.put(ed.DurableId, ed.QualifiedApiName);
                }

                for (Map<String, Object> rec : rawRecords) {
                    String objectName = idToObjectMap.get((String) rec.get('TableEnumOrId'));
                    String fieldName = (String) rec.get('DeveloperName');
                    if (objectName != null) {
                        fullNames.add(objectName + '.' + fieldName + '__c');
                    }
                }
            } else {
                System.debug('Tooling API error: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Exception in getFullCustomFieldNames: ' + e.getMessage());
        }

        return fullNames;
    }

    /**
 * @description Helper method to retrieve full API names of CustomObjects using Tooling API
 */
private static List<String> getCustomObjectApiNames(String likePattern) {
    List<String> objectApiNames = new List<String>();
    try {
        String query = 'SELECT DeveloperName, NamespacePrefix FROM CustomObject WHERE DeveloperName LIKE \'" + String.escapeSingleQuotes(likePattern) + "\' LIMIT 1000';

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + TOOLING_API_NAMED_CRED + '/services/data/v58.0/tooling/query/?q=' + EncodingUtil.urlEncode(query, 'UTF-8'));
        req.setMethod('GET');

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() == 200) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> records = (List<Object>) responseMap.get('records');

            for (Object recordObj : records) {
                Map<String, Object> record = (Map<String, Object>) recordObj;
                String devName = (String) record.get('DeveloperName');
                String nsPrefix = (String) record.get('NamespacePrefix');
                
                String apiName;
                if (String.isNotBlank(nsPrefix)) {
                    apiName = nsPrefix + '__' + devName + '__c';
                } else {
                    apiName = devName + '__c';
                }
                objectApiNames.add(apiName);
            }
        } else {
            System.debug(System.LoggingLevel.ERROR, 'Tooling API Error while retrieving CustomObject names: ' + res.getBody());
        }
    } catch (Exception e) {
        System.debug(System.LoggingLevel.ERROR, 'Exception in getCustomObjectApiNames: ' + e.getMessage());
    }
    return objectApiNames;
}

    /**
     * @description Helper to convert a list of SObjects to a Set of FeatureComponents for efficient lookup.
     */
    private static Set<FeatureComponent> createFeatureComponentSet(List<SObject> records) {
        Set<FeatureComponent> featureSet = new Set<FeatureComponent>();
        for (SObject record : records) {
            featureSet.add(new FeatureComponent(record));
        }
        return featureSet;
    }

    /**
     * @description Helper to create a PackageXMLWrapper instance.
     */
    private static PackageXMLWrapper createEntry(String type, String memberName) {
        PackageXMLWrapper entry = new PackageXMLWrapper();
        entry.type = type;
        //entry.member = memberName;
        entry.Name = memberName;
        return entry;
    }
}
