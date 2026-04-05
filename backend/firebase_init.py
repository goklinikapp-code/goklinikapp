import firebase_admin
from firebase_admin import credentials

cred = credentials.Certificate("firebase/goklinik-push-firebase-adminsdk-fbsvc-8aa7ab96ad.json")
firebase_admin.initialize_app(cred)