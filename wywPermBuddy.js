import { LightningElement, track } from 'lwc';

import getAllSObjectApiNames from '@salesforce/apex/wywPermBuddyController.getAllSObjectApiNames';
import getAllProfileNames from '@salesforce/apex/wywPermBuddyController.getAllProfileNames';
import getAllPermissionSetNames from '@salesforce/apex/wywPermBuddyController.getAllPermissionSetNames';
import getFieldsForObjects from '@salesforce/apex/wywPermBuddyController.getFieldsForObjects';
import exportPermissions from '@salesforce/apex/wywPermBuddyController.exportPermissions';
import processCsv from '@salesforce/apex/wywPermBuddyController.processCsv';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import wywFieldSampleCSV from '@salesforce/resourceUrl/wywFieldSampleCSV';
import wywObjectSampleCSV from '@salesforce/resourceUrl/wywObjectSampleCSV';

export default class WywPermBuddy extends LightningElement {
    @track mode = 'Export';
    @track targetType = 'Object';
    @track selectedObjects = [];
    @track selectedProfiles = [];
    @track selectedPermSets = [];
    @track selectedFields = [];
    @track objectOptions = [];
    @track profileOptions = [];
    @track permSetOptions = [];
    @track fieldOptions = [];
    @track fileContent = '';
    @track req = {};

    fieldSampleUrl = wywFieldSampleCSV;
    objectSampleUrl = wywObjectSampleCSV;

    modeOptions = [
        { label: 'Export', value: 'Export' },
        { label: 'Import', value: 'Import' }
    ];

    targetTypeOptions = [
        { label: 'Object', value: 'Object' },
        { label: 'Field', value: 'Field' }
    ];

    get showExport() {
        return this.mode === 'Export';
    }
    get showImport() {
        return this.mode === 'Import';
    }
    get showFieldSelect() {
        return this.targetType === 'Field' && this.showExport;
    }

    connectedCallback() {
        this.loadObjects();
        this.loadProfiles();
        this.loadPermSets();
    }

    // Load metadata for selectors
    loadObjects() {
        getAllSObjectApiNames().then(data => {
            this.objectOptions = data.map(o => ({ label: o, value: o }));
        });
    }
    loadProfiles() {
        getAllProfileNames().then(data => {
            this.profileOptions = data.map(p => ({ label: p, value: p }));
        });
    }
    loadPermSets() {
        getAllPermissionSetNames().then(data => {
            this.permSetOptions = data.map(p => ({ label: p, value: p }));
        });
    }
    loadFields() {
        if (this.selectedObjects.length > 0) {
            getFieldsForObjects({ objectApiNames: this.selectedObjects }).then(data => {
                this.fieldOptions = data.map(f => ({ label: f, value: f }));
            });
        } else {
            this.fieldOptions = [];
        }
    }

    handleModeChange(event) {
        this.mode = event.detail.value;
    }
    handleTargetTypeChange(event) {
        this.targetType = event.detail.value;
        this.selectedFields = [];
        this.loadFields();
    }
    handleObjectChange(event) {
        this.selectedObjects = event.detail;
        this.loadFields();
    }
    handleProfileChange(event) {
        this.selectedProfiles = event.detail;
    }
    handlePermSetChange(event) {
        this.selectedPermSets = event.detail;
    }
    handleFieldChange(event) {
        this.selectedFields = event.detail;
    }

    // Build request and trigger Apex export
    handleExport() {
        this.req = {
            exportType: this.targetType,
            objectApiNames: this.selectedObjects,
            profileNames: this.selectedProfiles,
            permSetNames: this.selectedPermSets,
            fieldApiNames: this.selectedFields
        };
        exportPermissions({ req: this.req })
            .then(csv => {
                this.downloadCSV(csv, `permissions_${this.targetType.toLowerCase()}.csv`);
                this.showToast('Export successful!', 'CSV file downloaded.', 'success');
            })
            .catch(err => {
                this.showToast('Export failed', this.reduceError(err), 'error');
            });
    }

    handleFileChange(event) {
        const file = event.target.files[0];
        if (file && file.name.toLowerCase().endsWith('.csv')) {
            const reader = new FileReader();
            reader.onload = () => { this.fileContent = reader.result; };
            reader.readAsText(file);
        } else {
            this.fileContent = '';
            this.showToast('Invalid file', 'Please upload a CSV file.', 'error');
        }
    }

    handleImport() {
        if (!this.fileContent) {
            this.showToast('Import failed', 'Please select a CSV file to import.', 'error');
            return;
        }
        processCsv({
            mode: 'Import',
            targetType: this.targetType,
            csvContent: this.fileContent
        })
            .then(() => {
                this.showToast('Import successful!', 'Permissions updated.', 'success');
            })
            .catch(err => {
                this.showToast('Import failed', this.reduceError(err), 'error');
            });
    }

    downloadCSV(csv, filename) {
        const blob = new Blob([csv], { type: 'text/csv' });
        const link = document.createElement('a');
        link.href = URL.createObjectURL(blob);
        link.download = filename;
        link.click();
        URL.revokeObjectURL(link.href);
    }

    reduceError(error) {
        if (Array.isArray(error.body)) {
            return error.body.map(e => e.message).join(', ');
        } else if (error.body && typeof error.body.message === 'string') {
            return error.body.message;
        }
        return error.message || JSON.stringify(error);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant,
                mode: 'dismissable'
            })
        );
    }
}
