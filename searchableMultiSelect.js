import { LightningElement, api, track } from 'lwc';

// Simple chip-based multi-select with search filtering
export default class SearchableMultiSelect extends LightningElement {
    @api label = '';
    @api options = [];

    @track selectedValues = [];
    @track searchTerm = '';

    get filteredOptions() {
        if (!this.searchTerm) {
            return [];
        }
        const term = this.searchTerm.toLowerCase();
        return this.options
            .filter(opt => opt.label.toLowerCase().includes(term) && !this.selectedValues.includes(opt.value));
    }

    getLabel(val) {
        const opt = this.options.find(o => o.value === val);
        return opt ? opt.label : val;
    }

    handleSearch(event) {
        this.searchTerm = event.target.value;
    }

    selectOption(event) {
        const value = event.currentTarget.dataset.value;
        if (!this.selectedValues.includes(value)) {
            this.selectedValues = [...this.selectedValues, value];
            this.dispatchChange();
        }
        this.searchTerm = '';
    }

    removeSelection(event) {
        const value = event.currentTarget.dataset.value;
        this.selectedValues = this.selectedValues.filter(v => v !== value);
        this.dispatchChange();
    }

    dispatchChange() {
        this.dispatchEvent(new CustomEvent('change', { detail: this.selectedValues }));
    }
}
