# Databricks notebook source
from pyspark.sql import functions as F
import pandas as pd
import numpy as np

# COMMAND ----------

spark.sql("USE CATALOG campaign_offer_analytics")
spark.sql("USE SCHEMA dataset")

# COMMAND ----------

df = spark.table("persona_clustering_features").toPandas()
 
spend_categories = ["travel", "dining", "grocery", "online_shopping", "gas", "entertainment", "utilities_bills"]
feature_cols = [f"{cat}_pct" for cat in spend_categories]
 
X = df[feature_cols].values
 
print(f"Clustering on {len(df)} customers using {len(feature_cols)} features")

# COMMAND ----------

from sklearn.preprocessing import StandardScaler
 
scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)

# COMMAND ----------

from sklearn.cluster import KMeans
 
inertias = []
k_range = range(2, 10)
for k in k_range:
    km = KMeans(n_clusters=k, random_state=42, n_init=10)
    km.fit(X_scaled)
    inertias.append(km.inertia_)
 
print("=== Elbow Method: Inertia by K ===")
for k, inertia in zip(k_range, inertias):
    print(f"K={k}: inertia={inertia:.2f}")
 
import matplotlib.pyplot as plt
plt.figure(figsize=(8, 5))
plt.plot(list(k_range), inertias, marker='o')
plt.xlabel('Number of Clusters (K)')
plt.ylabel('Inertia (within-cluster sum of squares)')
plt.title('Elbow Method for Optimal K')
plt.tight_layout()
display(plt.gcf())
plt.close()

# COMMAND ----------

final_k = 5
kmeans_final = KMeans(n_clusters=final_k, random_state=42, n_init=10)
df['cluster'] = kmeans_final.fit_predict(X_scaled)

# COMMAND ----------

cluster_profile = df.groupby('cluster')[feature_cols].mean().round(3)
print("\n=== Cluster Spend Profiles (avg % of spend per category) ===")
print(cluster_profile.to_string())

# COMMAND ----------

cluster_labels = {}
for cluster_id in cluster_profile.index:
    dominant_cat = cluster_profile.loc[cluster_id].idxmax()
    cluster_labels[cluster_id] = f"Cluster_{cluster_id}_{dominant_cat.replace('_pct','')}_dominant"
 
df['cluster_label'] = df['cluster'].map(cluster_labels)
print("\n=== Auto-generated cluster labels ===")
print(cluster_labels)

# COMMAND ----------

print("\n=== Validation: Cluster vs True Persona (cross-tab) ===")
crosstab = pd.crosstab(df['cluster_label'], df['true_persona'])
print(crosstab.to_string())

# COMMAND ----------

print("\n=== Cluster purity (% of cluster matching its dominant true persona) ===")
for cluster_id in sorted(df['cluster'].unique()):
    subset = df[df['cluster'] == cluster_id]
    most_common_persona = subset['true_persona'].mode()[0]
    purity = (subset['true_persona'] == most_common_persona).mean()
    print(f"Cluster {cluster_id} ({cluster_labels[cluster_id]}): "
          f"{purity*100:.1f}% match with '{most_common_persona}'")

# COMMAND ----------

offer_recommendation = {
    'travel': 'Travel Credit / Airline Miles Bonus',
    'dining': 'Dining Rewards Boost',
    'grocery': 'Cashback on Everyday Essentials',
    'online_shopping': 'Online Shopping Cashback',
    'gas': 'Gas Station Cashback',
    'entertainment': 'Streaming/Entertainment Credit',
    'utilities_bills': 'Bill Payment Cashback'
}
 
print("\n=== Recommended Offer per Cluster ===")
for cluster_id in cluster_profile.index:
    dominant_cat = cluster_profile.loc[cluster_id].idxmax().replace('_pct', '')
    recommended_offer = offer_recommendation.get(dominant_cat, 'General Cashback')
    cluster_size = (df['cluster'] == cluster_id).sum()
    print(f"Cluster {cluster_id} ({cluster_size} customers) -> Dominant: {dominant_cat} -> Recommend: {recommended_offer}")

# COMMAND ----------

export_df = df[['customer_id', 'true_persona', 'cluster', 'cluster_label', 'channel',
                'card_product', 'total_spend'] + feature_cols]
export_df.to_csv('/Volumes/campaign_offer_analytics/dataset/models/persona_clusters.csv', index=False)