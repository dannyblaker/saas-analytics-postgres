# Key Product Analytics Questions for SaaS Growth

This document outlines the critical analytics questions that a SaaS business needs to answer to drive growth, optimize conversions, and maximize revenue. The corresponding PostgreSQL database schema and analytics queries are designed to answer these questions.

## 📊 Revenue & Financial Metrics

### Sales Performance
- **Total volume of sales per plan** across different time periods (yesterday, 7 days, 30 days, 3 months, 6 months, 12 months)
- **Monthly Recurring Revenue (MRR) and Annual Recurring Revenue (ARR)** growth rates by plan
- **Revenue contribution by plan** - which plans drive the most revenue?
- **Average Revenue Per User (ARPU)** segmented by subscription plan
- **Seasonal revenue patterns** - are there usage-based or time-based revenue fluctuations?

### Customer Economics
- **Customer Lifetime Value (LTV)** differences across Free, Basic, and Premium plans
- **Revenue per customer segment** - which customer types are most profitable?
- **Plan upgrade/downgrade revenue impact** - financial effect of tier changes

## 🔄 Conversion & Upgrade Analytics

### Free-to-Paid Conversion
- **Free to paid conversion rate** - what percentage of Free users upgrade to paid plans?
- **Conversion by target tier** - do users prefer Basic or Premium when upgrading?
- **Time-to-upgrade analysis** - how long does it take users to convert from Free to paid?
- **Conversion rate optimization** - which factors correlate with higher conversion rates?

### Plan Movement
- **Upgrade/downgrade flows** - how many users change plans each month?
- **Cross-tier conversion rates** - Basic to Premium upgrade rates
- **Plan stickiness** - how long do users stay on each plan before changing?

## 📈 Retention & Churn Analysis

### Retention Metrics
- **Retention curves by plan** (Day 1, 7, 30, 90, 180, 365) for each subscription tier
- **Cohort retention analysis** - how do monthly signup cohorts retain over time?
- **Plan-based retention differences** - do Premium users stay significantly longer than Basic users?

### Churn Analysis
- **Churn rate by plan** (monthly and annual churn rates)
- **Cohort churn analysis** - churn patterns by signup month and user characteristics
- **Churn prediction indicators** - what behaviors signal increased churn risk?
- **Involuntary vs voluntary churn** - failed payments vs intentional cancellations

## 🎯 Activation & Engagement

### User Activation
- **Activation rate** - percentage of signups who complete onboarding and create their first project
- **Time-to-value** - how quickly do users reach their first meaningful interaction?
- **Activation by signup source** - which channels bring users who activate faster?

### Engagement Depth
- **Feature usage by plan** - projects created, tasks managed, team members invited
- **Power user identification** - who are the most engaged users and what do they do?
- **Engagement correlation with retention** - does higher engagement predict better retention?

## 🚀 Growth & Channel Analytics

### Acquisition Performance
- **Conversion funnel analysis** - signup → activation → paid subscription drop-off points
- **Channel performance comparison** - organic, paid ads, referrals, content marketing effectiveness
- **Geographic performance** - which countries/regions have the best conversion and retention?
- **UTM campaign analysis** - which specific campaigns drive the highest-value users?

### Marketing Efficiency
- **Channel-based churn rates** - are certain marketing channels bringing "high churn" users?
- **Customer acquisition cost (CAC) by channel** - relative cost-effectiveness of different acquisition sources
- **Payback period analysis** - how long to recoup acquisition costs by channel and plan?

## 📊 Operational Intelligence

### Business Health Metrics
- **Monthly cohort analysis** - how do user cohorts compare month-over-month?
- **Plan popularity trends** - are users gravitating toward specific plans over time?
- **Feature adoption rates** - which features correlate with upgrade and retention?

### Funnel Optimization
- **Conversion rate at each funnel stage** - signup, email verification, onboarding, activation, payment
- **Drop-off analysis** - where do we lose the most potential customers?
- **A/B test impact measurement** - quantifying the effect of product and marketing changes

## 🎯 Strategic Questions

### Product Development
- **Feature usage correlation with plan upgrades** - which features drive users to pay more?
- **Onboarding effectiveness** - does our onboarding process improve activation and retention?
- **Team collaboration impact** - do users who invite teammates retain and upgrade better?

### Market Positioning
- **Competitive benchmarking** - how do our metrics compare to industry standards?
- **Price sensitivity analysis** - how do pricing changes affect conversion and churn?
- **Market segment performance** - which user types (company size, industry, role) perform best?

---

*This comprehensive analytics framework ensures we can measure, understand, and optimize every aspect of our SaaS growth engine using the power of PostgreSQL and SQL analytics.*