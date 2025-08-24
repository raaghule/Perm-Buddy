@isTest
private class wywPermBuddyControllerTest {

    private static Profile getAnyProfile() {
        return [SELECT Id, Name FROM Profile LIMIT 1];
    }

    private static PermissionSet getAnyPermSet() {
        PermissionSet ps = [SELECT Id, Name, IsOwnedByProfile FROM PermissionSet WHERE IsOwnedByProfile = false LIMIT 1];
        if (ps == null) {
            ps = [SELECT Id, Name FROM PermissionSet LIMIT 1];
        }
        return ps;
    }

    @isTest
    static void fieldImportExport() {
        Profile prof = getAnyProfile();
        PermissionSet ps = getAnyPermSet();
        String header = 'Object API Name,Field API Name,Persona,Persona API Name,Access\n';
        String csv1 = header +
            'Account,Name,Profile,' + prof.Name + ',Edit\n' +
            'Account,Name,PermissionSet,' + ps.Name + ',Read';
        String csv2 = header +
            'Account,Name,Profile,' + prof.Name + ',Read\n' +
            'Account,Name,PermissionSet,' + ps.Name + ',Edit';

        Test.startTest();
        wywPermBuddyController.processCsv('Import','Field',csv1);
        wywPermBuddyController.processCsv('Import','Field',csv2);
        wywPermBuddyController.ExportRequest req = new wywPermBuddyController.ExportRequest();
        req.exportType = 'Field';
        req.objectApiNames = new List<String>{'Account'};
        req.fieldApiNames = new List<String>{'Account.Name'};
        req.profileNames = new List<String>{prof.Name};
        req.permSetNames = new List<String>{ps.Name};
        String res = wywPermBuddyController.exportPermissions(req);
        Test.stopTest();

        System.assert(res.contains('Account,Name,Profile,' + prof.Name), 'Profile field row expected');
        System.assert(res.contains('Account,Name,PermissionSet,' + ps.Name), 'Perm set field row expected');
    }

    @isTest
    static void objectImportExport() {
        Profile prof = getAnyProfile();
        PermissionSet ps = getAnyPermSet();
        String header = 'Object API Name,Persona,Persona API Name,Read,Edit,Create,Delete,View All,Modify All\n';
        String csv1 = header +
            'Account,Profile,' + prof.Name + ',true,false,false,false,false,false\n' +
            'Account,PermissionSet,' + ps.Name + ',true,false,false,false,false,false';
        String csv2 = header +
            'Account,Profile,' + prof.Name + ',true,true,false,false,false,false\n' +
            'Account,PermissionSet,' + ps.Name + ',true,false,true,false,false,false';

        Test.startTest();
        wywPermBuddyController.processCsv('Import','Object',csv1);
        wywPermBuddyController.processCsv('Import','Object',csv2);
        wywPermBuddyController.ExportRequest req = new wywPermBuddyController.ExportRequest();
        req.exportType = 'Object';
        req.objectApiNames = new List<String>{'Account'};
        req.profileNames = new List<String>{prof.Name};
        req.permSetNames = new List<String>{ps.Name};
        String res = wywPermBuddyController.exportPermissions(req);
        Test.stopTest();

        System.assert(res.contains('Account,Profile,' + prof.Name), 'Profile object row expected');
        System.assert(res.contains('Account,PermissionSet,' + ps.Name), 'Perm set object row expected');
    }

    @isTest
    static void utilityCalls() {
        Profile prof = getAnyProfile();
        Test.startTest();
        List<String> objs = wywPermBuddyController.getAllSObjectApiNames();
        List<String> profs = wywPermBuddyController.getAllProfileNames();
        List<String> perms = wywPermBuddyController.getAllPermissionSetNames();
        List<String> fields = wywPermBuddyController.getFieldsForObjects(new List<String>{'Account'});
        Test.stopTest();

        System.assert(objs.contains('Account'), 'Objects should include Account');
        System.assert(!profs.isEmpty(), 'Profiles should not be empty');
        System.assert(!perms.isEmpty(), 'Permission sets should not be empty');
        System.assert(!fields.isEmpty(), 'Fields list should not be empty');
    }
}
