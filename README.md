# Acquisition Campaign & Offer Analytics

A marketing analytics project simulating how a credit card company measures campaign performance 
across channels and segments customers by spending behavior, using SQL, PySpark (Databricks), and 
unsupervised machine learning (K-means clustering).

---

## Business Problem

Credit card companies run acquisition campaigns across multiple channels (email, social media, 
search ads, TV, etc.) and need to know which channels are actually cost-effective at bringing in 
new customers. Separately, understanding what customers spend on (travel, dining, groceries, etc.) 
helps decide which offers or rewards to show each customer. This project addresses both questions: 
which channels perform best, and what customer spending personas exist for offer targeting.

---

## Dataset

A realistic, relational, synthetic dataset simulating a year of acquisition campaigns and customer 
spending behavior.

| Table | Rows | Description |
|---|---|---|
| `campaigns` | 60 | Campaign metadata: channel, card product, offer type, budget, dates |
| `campaign_funnel` | 60 | Impressions → clicks → applications → approvals → activations per campaign |
| `acquired_customers` | ~45,949 | One row per customer acquired, linked to source campaign/channel |
| `customer_spend_by_category` | ~45,949 | Spend across 7 categories per customer, with a hidden true persona label |
| `offer_redemptions` | ~31,277 | Which acquired customers redeemed their welcome offer, and when |

Channel-specific conversion rates were built into the funnel data (e.g., In-App and Search Ads 
convert at meaningfully higher rates than TV), so the cost-per-acquisition analysis reflects a 
realistic, defensible channel-performance story rather than random noise.

Customer spend was generated from 5 underlying persona archetypes (Frequent Traveler, Dining 
Enthusiast, Everyday Essentials, Online Shopper, Balanced Spender), each with a different weighted 
distribution of spend across categories. The true persona label was kept hidden during clustering 
and used only afterward to validate the clustering results.

*Note: This is synthetic data designed to mimic realistic campaign and spending behavior. It is 
used to demonstrate methodology and approach, not to represent real-world campaign statistics.*

---

## Tech Stack

- **SQL** (Databricks SQL)
- **PySpark** (Databricks) — feature engineering
- **Python** (pandas, scikit-learn) — K-means clustering and evaluation
- **Power BI** — dashboard *(in progress — see below)*

---

## Approach

### 1. SQL Analysis
Built 10 investigative SQL queries (`sql/campaign_queries.sql`) covering:
- Full funnel conversion rates by channel (impressions through activations)
- Cost-per-activation ranking across channels using `RANK()`
- Month-over-month activation trend using `LAG()`
- Best-performing campaign per card product using `DENSE_RANK()`
- Offer redemption rate by offer type
- Customer spend percentiles by category using `PERCENT_RANK()`
- Spend summary by persona archetype (validating distinct spend patterns before clustering)
- Channel performance vs. overall average, using a self-referencing comparison
- ROI by card product across multiple joined tables
- Geographic distribution of acquired customers

**Key finding:** In-App and Search Ads channels had the lowest cost-per-activation, while TV had 
by far the highest — a clear, actionable channel-investment insight.

### 2. Feature Engineering (PySpark)
Converted raw category spend into **percentage of total spend per category**, rather than using 
raw dollar amounts. This was a deliberate choice: two customers spending $500 and $5,000 respectively, 
both with 40% of that going to travel, represent the same underlying persona — using raw dollars 
instead would have clustered customers by how much money they have rather than what they spend it on.

### 3. Modeling: K-Means Clustering
Since this is a customer-segmentation problem rather than a prediction problem, K-means clustering 
(unsupervised learning) was used instead of a classification model:
- Used the elbow method to evaluate an appropriate number of clusters (K)
- Trained the final model with K=5, matching the business hypothesis of 5 distinct spending personas
- Auto-labeled each cluster by its dominant spending category
- **Validated the discovered clusters against the hidden true persona labels** — since this is 
  synthetic data with known ground truth, this step confirms the clustering approach genuinely 
  recovers meaningful segments rather than arbitrary groupings
- Mapped each cluster to a recommended offer type (e.g., a travel-dominant cluster → travel credit offer)

---

## Results

**Cluster validation (purity against true persona):** *(add your actual purity percentages here)*

**Cluster → Recommended offer mapping:** *(add your actual cluster-to-offer output here)*

*(Fill in from your clustering script output)*

---

## Power BI Dashboard 

A dashboard is being built to present the SQL and clustering results in a business-facing format, 
including:
- Funnel conversion by channel
- Cost-per-activation comparison across channels
- Customer persona cluster distribution
- Recommended offer type by cluster


---

## What I'd Do With More Time
- Test alternative clustering approaches (e.g., hierarchical clustering) for comparison against K-means
- Build a simple text-to-SQL layer so non-technical stakeholders could query campaign performance directly
- Incorporate customer lifetime value into the offer-recommendation logic, not just spend category
- Validate the approach against real (non-synthetic) campaign and spend data

---

## Repository Structure
```
campaign-offer-analytics/
├── README.md
├── sql/
│   └── campaign_queries.sql
├── pyspark/
│   └── persona_features.py
├── modeling/
│   └── kmeans_clustering.py
```
