public with sharing class wywPermBuddyController {

    @AuraEnabled
    public class ExportRequest {

        @AuraEnabled public String exportType; // 'Object' or 'Field'

        @AuraEnabled public List<String> objectApiNames;

        @AuraEnabled public List<String> profileNames;

        @AuraEnabled public List<String> permSetNames; // Use Name, not DeveloperName

        @AuraEnabled public List<String> fieldApiNames; // For field export, format: Object.Field



    }

    @AuraEnabled

    public static void processCsv(String mode, String targetType, String csvContent) {

        if (String.isBlank(mode) || String.isBlank(targetType)) {

            throw new AuraHandledException('Mode and Target Type are required.');

        }

        if (mode == 'Export') {

            throw new AuraHandledException('Export is not supported via import endpoint.');

        }

        if (String.isBlank(csvContent)) {

            throw new AuraHandledException('No CSV content provided.');

        }

        // Normalize line endings and remove empty lines

        List<String> lines = new List<String>();

        for (String raw : csvContent.replace('\r\n', '\n').replace('\r', '\n').split('\n')) {

            if (String.isNotBlank(raw)) lines.add(raw.trim());

        }

        if (lines.size() < 2) {

            throw new AuraHandledException('CSV must contain headers and at least one data row.');

        }

        // Header validation

        String header = lines[0].trim();

        if (targetType == 'Field') {

            String expected = 'Object API Name,Field API Name,Persona,Persona API Name,Access';

            if (header != expected) {

                throw new AuraHandledException('Invalid CSV header for Field Import. Expected: ' + expected);

            }

            applyFieldPermissions(lines);

        } else if (targetType == 'Object') {

            String expected = 'Object API Name,Persona,Persona API Name,Read,Edit,Create,Delete,View All,Modify All';

            if (header != expected) {

                throw new AuraHandledException('Invalid CSV header for Object Import. Expected: ' + expected);

            }

            applyObjectPermissions(lines);

        } else {

            //throw new AuraHandledException('Invalid target type: ' + targetType);

        }

    }

    // ---------------- Field Permissions ----------------

    private static void applyFieldPermissions(List<String> lines) {

        List<List<String>> rows = parseSimpleCsv(lines);

        if (rows.isEmpty()) {

            throw new AuraHandledException('No data rows found.');

        }

        Set<String> profileNames = new Set<String>();

        Set<String> permSetNames = new Set<String>();

        for (List<String> cols : rows) {

            if (cols.size() < 5) continue;

            String personaKind = cols[2].trim();

            String personaApi = cols[3].trim();

            if (personaKind == 'Profile') profileNames.add(personaApi);

            else if (personaKind == 'PermissionSet') permSetNames.add(personaApi);

        }

        Map<String, Id> profileByName = new Map<String, Id>();

        if (!profileNames.isEmpty()) {

            for (Profile p : [SELECT Id, Name FROM Profile WHERE Name IN :profileNames]) {

                profileByName.put(p.Name, p.Id);

            }

        }

        Map<String, Id> permSetByName = new Map<String, Id>();

        if (!permSetNames.isEmpty()) {

            for (PermissionSet ps : [SELECT Id, Name FROM PermissionSet WHERE Name IN :permSetNames]) {

                permSetByName.put(ps.Name, ps.Id);

            }

        }

        List<FieldPermissions> desired = new List<FieldPermissions>();

        for (List<String> cols : rows) {

            if (cols.size() < 5) continue;

            String sObjectName = cols[0].trim();

            String fieldApi = cols[1].trim();

            String personaKind = cols[2].trim();

            String personaApi = cols[3].trim();

            String access = cols[4].trim();


            Id parentId;

            if (personaKind == 'Profile') parentId = profileByName.get(personaApi);

            else if (personaKind == 'PermissionSet') parentId = permSetByName.get(personaApi);

            else continue;

            if (parentId == null) continue;

            FieldPermissions fp = new FieldPermissions();

            fp.ParentId = parentId;

            fp.SObjectType = sObjectName;

            fp.Field = sObjectName + '.' + fieldApi;

            fp.PermissionsRead = (access == 'Read' || access == 'Edit');

            fp.PermissionsEdit = (access == 'Edit');

            desired.add(fp);

        }

        if (desired.isEmpty()) return;

        try {

            upsertFieldPermissions(desired);

        } catch (Exception e) {

            throw new AuraHandledException('Failed to update Field Permissions. Please check your data and try again.');

        }

    }

    private static void upsertFieldPermissions(List<FieldPermissions> desired) {

        Set<Id> parentIds = new Set<Id>();

        Set<String> fields = new Set<String>();

        for (FieldPermissions fp : desired) {

            parentIds.add(fp.ParentId);

            fields.add(fp.Field);

        }

        Map<String, FieldPermissions> existingByKey = new Map<String, FieldPermissions>();

        for (FieldPermissions ex : [

            SELECT Id, ParentId, Field, PermissionsRead, PermissionsEdit

            FROM FieldPermissions

            WHERE ParentId IN :parentIds AND Field IN :fields

        ]) {

            existingByKey.put(ex.ParentId + '|' + ex.Field, ex);

        }

        List<FieldPermissions> toInsert = new List<FieldPermissions>();

        List<FieldPermissions> toUpdate = new List<FieldPermissions>();

        for (FieldPermissions fp : desired) {

            String key = fp.ParentId + '|' + fp.Field;

            if (existingByKey.containsKey(key)) {

                FieldPermissions ex = existingByKey.get(key);

                ex.PermissionsRead = fp.PermissionsRead;

                ex.PermissionsEdit = fp.PermissionsEdit;

                toUpdate.add(ex);

            } else {

                toInsert.add(fp);

            }

        }

        if (!toInsert.isEmpty()) insert toInsert;

        if (!toUpdate.isEmpty()) update toUpdate;

    }

    // ---------------- Object Permissions ----------------

    private static void applyObjectPermissions(List<String> lines) {

        List<List<String>> rows = parseSimpleCsv(lines);

        if (rows.isEmpty()) {

            throw new AuraHandledException('No data rows found.');

        }

        Set<String> profileNames = new Set<String>();


        Set<String> permSetNames = new Set<String>();

        for (List<String> cols : rows) {

            if (cols.size() < 9) continue;

            String personaKind = cols[1].trim();


            String personaApi = cols[2].trim();

            if (personaKind == 'Profile') profileNames.add(personaApi);

            else if (personaKind == 'PermissionSet') permSetNames.add(personaApi);




        }


        Map<String, Id> profileByName = new Map<String, Id>();

        if (!profileNames.isEmpty()) {

            for (Profile p : [SELECT Id, Name FROM Profile WHERE Name IN :profileNames]) {

                profileByName.put(p.Name, p.Id);

            }

        }

        Map<String, Id> permSetByName = new Map<String, Id>();

        if (!permSetNames.isEmpty()) {

            for (PermissionSet ps : [SELECT Id, Name FROM PermissionSet WHERE Name IN :permSetNames]) {

                permSetByName.put(ps.Name, ps.Id);

            }

        }

        List<ObjectPermissions> desired = new List<ObjectPermissions>();

        for (List<String> cols : rows) {

            if (cols.size() < 9) continue;

            String sObjectName = cols[0].trim();

            String personaKind = cols[1].trim();

            String personaApi = cols[2].trim();

            Boolean canRead   = toBool(cols[3]);

            Boolean canEdit   = toBool(cols[4]);

            Boolean canCreate = toBool(cols[5]);

            Boolean canDelete = toBool(cols[6]);

            Boolean viewAll   = toBool(cols[7]);

            Boolean modifyAll = toBool(cols[8]);


            Id parentId;

            if (personaKind == 'Profile') parentId = profileByName.get(personaApi);


            else if (personaKind == 'PermissionSet') parentId = permSetByName.get(personaApi);


            else continue;

            if (parentId == null) continue; // skip unknown parent


            ObjectPermissions op = new ObjectPermissions();

            op.ParentId = parentId;

            op.SObjectType = sObjectName;

            op.PermissionsRead = canRead;

            op.PermissionsEdit = canEdit;

            op.PermissionsCreate = canCreate;

            op.PermissionsDelete = canDelete;

            op.PermissionsViewAllRecords = viewAll;

            op.PermissionsModifyAllRecords = modifyAll;

            desired.add(op);

        }

        if (desired.isEmpty()) return;

        try {

            upsertObjectPermissions(desired);

        } catch (Exception e) {

            throw new AuraHandledException('Failed to update Object Permissions. Please check your data and try again.');

        }

    }

    private static void upsertObjectPermissions(List<ObjectPermissions> desired) {

        Set<Id> parentIds = new Set<Id>();

        Set<String> types = new Set<String>();

        for (ObjectPermissions op : desired) {

            parentIds.add(op.ParentId);

            types.add(op.SObjectType);

        }

        Map<String, ObjectPermissions> existingByKey = new Map<String, ObjectPermissions>();

        for (ObjectPermissions ex : [

            SELECT Id, ParentId, SObjectType,

                   PermissionsRead, PermissionsEdit, PermissionsCreate, PermissionsDelete,

                   PermissionsViewAllRecords, PermissionsModifyAllRecords

            FROM ObjectPermissions

            WHERE ParentId IN :parentIds AND SObjectType IN :types

        ]) {

            existingByKey.put(ex.ParentId + '|' + ex.SObjectType, ex);

        }

        List<ObjectPermissions> toInsert = new List<ObjectPermissions>();

        List<ObjectPermissions> toUpdate = new List<ObjectPermissions>();

        for (ObjectPermissions op : desired) {

            String key = op.ParentId + '|' + op.SObjectType;

            if (existingByKey.containsKey(key)) {

                ObjectPermissions ex = existingByKey.get(key);

                ex.PermissionsRead = op.PermissionsRead;

                ex.PermissionsEdit = op.PermissionsEdit;

                ex.PermissionsCreate = op.PermissionsCreate;

                ex.PermissionsDelete = op.PermissionsDelete;

                ex.PermissionsViewAllRecords = op.PermissionsViewAllRecords;

                ex.PermissionsModifyAllRecords = op.PermissionsModifyAllRecords;

                toUpdate.add(ex);

            } else {

                toInsert.add(op);

            }

        }

        if (!toInsert.isEmpty()) insert toInsert;

        if (!toUpdate.isEmpty()) update toUpdate;

    }

    // ---------------- EXPORT FUNCTIONALITY ----------------

    @AuraEnabled(cacheable=true)

    public static List<String> getAllSObjectApiNames() {

        List<String> names = new List<String>();

        for (Schema.SObjectType sObj : Schema.getGlobalDescribe().values()) {

            names.add(sObj.getDescribe().getName());

        }

        names.sort();

        return names;

    }

    @AuraEnabled(cacheable=true)
    @AuraEnabled(cacheable=true)
    public static List<String> getAllProfileNames() {
        List<String> names = new List<String>();
        for (Profile p : [SELECT Name FROM Profile]) {
            names.add(p.Name);
        }
        names.sort();
        return names;
    }

    @AuraEnabled(cacheable=true)

    public static List<String> getAllPermissionSetNames() {
        List<String> names = new List<String>();
        for (PermissionSet ps : [SELECT Name FROM PermissionSet]) {
            names.add(ps.Name);
        }
        names.sort();
        return names;
    }

    @AuraEnabled(cacheable=true)

    public static List<String> getFieldsForObjects(List<String> objectApiNames) {

        Set<String> fields = new Set<String>();

        for (String objApi : objectApiNames) {

            Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(objApi).getDescribe().fields.getMap();

            for (String f : fieldMap.keySet()) {

                fields.add(objApi + '.' + f);

            }

        }

        return new List<String>(fields);

    }

    @AuraEnabled

    public static String exportPermissions(ExportRequest req) {
        if (req == null || String.isBlank(req.exportType)) {
            throw new AuraHandledException('Export type is required.');
        }
        List<String> rows = new List<String>();
        Integer recordCount = 0;
        Integer recordLimit = 10000;

        if (req.exportType == 'Object') {
            rows.add('Object API Name,Persona,Persona API Name,Read,Edit,Create,Delete,View All,Modify All');
            if (req.objectApiNames == null || req.objectApiNames.isEmpty() ||
                ((req.profileNames == null || req.profileNames.isEmpty()) &&
                 (req.permSetNames == null || req.permSetNames.isEmpty()))) {
                throw new AuraHandledException('Please select at least one object and persona.');
            }
            // Collect profile ids by name
            Map<String, Id> profileIdMap = new Map<String, Id>();
            if (req.profileNames != null && !req.profileNames.isEmpty()) {
                for (Profile p : [SELECT Id, Name FROM Profile WHERE Name IN :req.profileNames]) {
                    profileIdMap.put(p.Name, p.Id);
                }
            }
            // Collect permission set ids by name
            Map<String, Id> permSetIdMap = new Map<String, Id>();
            if (req.permSetNames != null && !req.permSetNames.isEmpty()) {
                for (PermissionSet ps : [SELECT Id, Name FROM PermissionSet WHERE Name IN :req.permSetNames]) {
                    permSetIdMap.put(ps.Name, ps.Id);
                }
            }
            Set<Id> personaIds = new Set<Id>();
            personaIds.addAll(profileIdMap.values());
            personaIds.addAll(permSetIdMap.values());

            // Query object permissions for selected personas
            List<ObjectPermissions> perms = [
                SELECT SObjectType, ParentId, PermissionsRead, PermissionsEdit, PermissionsCreate, PermissionsDelete, PermissionsViewAllRecords, PermissionsModifyAllRecords
                FROM ObjectPermissions
                WHERE SObjectType IN :req.objectApiNames AND ParentId IN :personaIds
            ];
            Map<Id, String> profileNameById = new Map<Id, String>();
            for (String name : profileIdMap.keySet()) profileNameById.put(profileIdMap.get(name), name);
            Map<Id, String> permSetNameById = new Map<Id, String>();
            for (String name : permSetIdMap.keySet()) permSetNameById.put(permSetIdMap.get(name), name);

            // Build CSV rows
            for (ObjectPermissions op : perms) {
                if (++recordCount > recordLimit) throw new AuraHandledException('Export limit exceeded (10,000 records). Please reduce your selection.');
                String personaType;
                String personaApi;
                if (profileNameById.containsKey(op.ParentId)) {
                    personaType = 'Profile';
                    personaApi = profileNameById.get(op.ParentId);
                } else {
                    personaType = 'PermissionSet';
                    personaApi = permSetNameById.get(op.ParentId);
                }
                rows.add(String.join(new List<String>{
                    op.SObjectType,
                    personaType,
                    personaApi,
                    op.PermissionsRead ? 'True' : 'False',
                    op.PermissionsEdit ? 'True' : 'False',
                    op.PermissionsCreate ? 'True' : 'False',
                    op.PermissionsDelete ? 'True' : 'False',
                    op.PermissionsViewAllRecords ? 'True' : 'False',
                    op.PermissionsModifyAllRecords ? 'True' : 'False'
                }, ','));
            }
        } else if (req.exportType == 'Field') {
            rows.add('Object API Name,Field API Name,Persona,Persona API Name,Access');
            if (req.objectApiNames == null || req.objectApiNames.isEmpty() ||
                req.fieldApiNames == null || req.fieldApiNames.isEmpty() ||
                ((req.profileNames == null || req.profileNames.isEmpty()) &&
                 (req.permSetNames == null || req.permSetNames.isEmpty()))) {
                throw new AuraHandledException('Please select at least one object, field, and persona.');
            }
            // Collect profile ids by name
            Map<String, Id> profileIdMap = new Map<String, Id>();
            if (req.profileNames != null && !req.profileNames.isEmpty()) {
                for (Profile p : [SELECT Id, Name FROM Profile WHERE Name IN :req.profileNames]) {
                    profileIdMap.put(p.Name, p.Id);
                }
            }
            // Collect permission set ids by name
            Map<String, Id> permSetIdMap = new Map<String, Id>();
            if (req.permSetNames != null && !req.permSetNames.isEmpty()) {
                for (PermissionSet ps : [SELECT Id, Name FROM PermissionSet WHERE Name IN :req.permSetNames]) {
                    permSetIdMap.put(ps.Name, ps.Id);
                }
            }
            Set<Id> personaIds = new Set<Id>();
            personaIds.addAll(profileIdMap.values());
            personaIds.addAll(permSetIdMap.values());

            Set<String> fieldKeys = new Set<String>(req.fieldApiNames);
            // Query field permissions for selected personas
            List<FieldPermissions> perms = [
                SELECT SObjectType, Field, ParentId, PermissionsRead, PermissionsEdit
                FROM FieldPermissions
                WHERE ParentId IN :personaIds
            ];
            Map<Id, String> profileNameById = new Map<Id, String>();
            for (String name : profileIdMap.keySet()) profileNameById.put(profileIdMap.get(name), name);
            Map<Id, String> permSetNameById = new Map<Id, String>();
            for (String name : permSetIdMap.keySet()) permSetNameById.put(permSetIdMap.get(name), name);

            // Build CSV rows
            for (FieldPermissions fp : perms) {
                String[] parts = fp.Field.split('\\.');
                if (parts.size() != 2) continue;
                String objApi = parts[0];
                String fieldApi = parts[1];
                if (!req.objectApiNames.contains(objApi)) continue;
                if (!fieldKeys.contains(fp.Field)) continue;
                if (++recordCount > recordLimit) throw new AuraHandledException('Export limit exceeded (10,000 records). Please reduce your selection.');
                String personaType;
                String personaApi;
                if (profileNameById.containsKey(fp.ParentId)) {
                    personaType = 'Profile';
                    personaApi = profileNameById.get(fp.ParentId);
                } else {
                    personaType = 'PermissionSet';
                    personaApi = permSetNameById.get(fp.ParentId);
                }
                if (fp.PermissionsRead) {
                    rows.add(String.join(new List<String>{
                        objApi,
                        fieldApi,
                        personaType,
                        personaApi,
                        fp.PermissionsEdit ? 'Edit' : 'Read'
                    }, ','));
                }
            }
        } else {
            throw new AuraHandledException('Invalid export type.');
        }
        if (recordCount == 0) {
            throw new AuraHandledException('No permissions found for specified criteria.');
        }
        return String.join(rows, '\n');
    }

    // ----------- Helper Methods -----------

    // Converts a string value to Boolean

    //

/**

* Converts a string value to Boolean.

* Accepts: 'true', 'True', 'TRUE', '1', 'yes', 'Yes', 'Y', 'y'

* Returns true for any of the above, false otherwise.

*/

private static Boolean toBool(String val) {

    if (val == null) return false;

    String v = val.trim().toLowerCase();

    return v == 'true' || v == '1' || v == 'yes' || v == 'y';

}

/**

* Parses a simple CSV (no quoted commas) into a list of lists of strings.

* Skips the header row.

*/

private static List<List<String>> parseSimpleCsv(List<String> lines) {

    List<List<String>> rows = new List<List<String>>();

    for (Integer i = 1; i < lines.size(); i++) {

        String line = lines[i];

        // Split by comma, trim each cell

        List<String> cols = new List<String>();

        for (String cell : line.split(',')) {

            cols.add(cell.trim());

        }

        rows.add(cols);

    }

    return rows;

}

}
