<template>
  <step-base v-bind:step="step">
    <executors v-bind:step="step" v-if="step.currentPage == 0"></executors>
    <spouse v-bind:step="step" v-if="step.currentPage == 1"></spouse>
    <children v-bind:step="step" v-if="step.currentPage == 2"></children>
    <grand-children v-bind:step="step" v-if="step.currentPage == 3"></grand-children>
    <beneficiaries v-bind:step="step" v-if="step.currentPage == 4"></beneficiaries>
    <creditors v-bind:step="step" v-if="step.currentPage == 5"></creditors>
  </step-base>
</template>

<script lang="ts">
import { Component, Vue, Prop} from 'vue-property-decorator';

import StepBase from "../StepBase.vue";
import { stepInfoType } from "@/types/Application";
import Executors from "./Executors.vue";
import Spouse from "./Spouse.vue";
import Children from "./Children.vue";
import GrandChildren from "./GrandChildren.vue";
import Beneficiaries from "./Beneficiaries.vue";
import Creditors from "./Creditors.vue";


@Component({
    components:{
        StepBase,
        Executors,
        Spouse,
        Children,
        GrandChildren,
        Beneficiaries,
        Creditors
    }
})

export default class RelatedPeopleStep extends Vue {
    
    @Prop({required: true})
    step!: stepInfoType;


};
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style lang="scss">
@import "../../../styles/survey";
</style>
