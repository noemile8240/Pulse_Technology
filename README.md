# Pulse-Technology-Analysis — Sales & Customer Analytics (2019–2022)
End-to-end **SQL and Tableau business intelligence analysis** evaluating revenue trends, customer behavior, product performance, refunds, and regional growth for a consumer electronics company navigating COVID-era demand shifts.


# Business Objective

Leadership requested a **data-driven performance review** to support preparation for a 2023 company-wide town hall, focusing on:
 Revenue trends before, during, and after COVID  
- Key growth drivers across products and regions  
- Loyalty program performance and retention behavior  
- Refund risk and customer value indicators  

- Revenue trends before, during, and after COVID  
- Key growth drivers across products and regions  
- Loyalty program performance and retention behavior  
- Refund risk and customer value indicators  

---
## Tools & Methods

- **SQL:** data cleaning, joins, aggregations, KPI analysis  
- **Tableau:** executive dashboard design and visualization  
- **Data Modeling:** relational schema with ERD validation  
- **Business Analysis:** revenue trends, AOV, loyalty impact, refund risk  

---


# Executive Summary

-  Revenue surged during COVID (peaking Q4 2020) and stabilized at a **higher post-COVID baseline**, indicating durable demand rather than temporary lift.  
- Revenue is concentrated in a **small number of top-performing products**, creating both growth leverage and concentration risk.  
- **Loyalty customers provide more stable repeat revenue**, reinforcing retention-focused strategy over short-term AOV gains.  

 <img src="Images/Executive_Summary-2.png" width="800">

---


# Data Structure

Relational dataset composed of four core tables:

- `orders` — transactional purchases  
- `customers` — attributes and loyalty status  
- `order_status` — fulfillment and refund lifecycle  
- `geo_lookup` — country-to-region mapping  


An ERD illustrating table relationships is included below.
 <img src="Images/ERD.png" width="600">
---

# Data Cleaning & Assumptions

Data quality issues were reviewed and logged prior to analysis. Only issues with a clear resolution and minimal business risk were addressed.

Actions taken included:

* Standardizing inconsistent product naming

* Normalizing date formats

* Replacing blank marketing channels with “Unknown”

* Correcting invalid or missing region values where country codes were known

No action was taken on records lacking a reliable source of truth (e.g., zero-dollar prices, missing currencies, or anomalous timestamps) due to their minimal impact on aggregate results.

***Full issue log and resolutions are documented in the repository.***


# Key Insights & Findings


### 1. Revenue Trends & Growth
 <img src="Images/qrterlygrowth.png" width="800">

* Revenue peaked in Q4 2020 during COVID demand surge.

* Post-COVID revenue stabilized at a higher baseline than pre-pandemic levels.

* Quarterly analysis revealed a gradual deceleration through 2022, consistent with demand normalization.<br><br>

###  2. Product Performance
 <img src="Images/Product_Performance_Analysis-2.png" width="800">
 
* Accessories (e.g., AirPods, monitors) drive order volume.

* Laptops command the highest Average Order Value.

* The top three products account for the majority of total revenue, indicating revenue concentration risk.<br><br>

###  3. Loyalty Program Performance
 <img src="Images/Loyalty_Analysis.png" width="800">
 
* Loyalty members represent a smaller share of customers but show higher repeat purchase behavior.

* Loyalty revenue proved more stable post-COVID compared to non-member sales.

* AOV differences narrowed over time, suggesting loyalty benefits retention more than basket size.<br><br>

###  4. Regional Performance Insights
 <img src="Images/Regional_Analysis.png" width="800">
 
* North America is the primary revenue driver, contributing ~52% of total sales and consistently leading monthly revenue across all periods.
Global demand surged during COVID, with all regions showing a noticeable lift, though North America experienced the strongest absolute growth.

* APAC demonstrates the highest average order value (~$279), despite contributing a smaller share of total revenue, indicating higher-value purchases but lower order volume.
* EMEA represents a meaningful secondary market, accounting for ~29% of total sales with relatively stable AOV trends.
* LATAM remains a smaller growth opportunity, contributing ~6% of total sales with the lowest average order value among regions.<br><br>


### 5. Refunds & Risk
 <img src="Images/refund.png" width="800" >
 
* Refund rates are highest for premium laptop products, indicating higher per-order risk.

* High-volume accessories generate more refunds in absolute terms but lower refund rates.

* Refund risk is driven by product type rather than order volume alone.

# Business Recommendations

* Diversify revenue drivers by expanding mid-tier products to reduce reliance on top SKUs.

* Continue investing in the loyalty program, focusing on retention and lifecycle value rather than short-term AOV lift.

* Monitor premium product refunds to reduce high-value loss exposure.

* Strengthen regional growth strategies outside North America, particularly in EMEA and APAC.


# Repository Contents

* noemile8240/ Pulse_Technology /sql/ — Data cleaning & analysis queries

* noemile8240/ Pulse_Technology /tableau/ — Dashboard screenshots

* noemile8240/ Pulse_Technology /images/ — ERD and visual assets

* noemile8240/ Pulse_Technology README.md — Project documentation

🔗 Tableau Dashboard

👉 [Link to Tableau Public Dashboard]
