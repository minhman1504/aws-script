## **Argument Definition**
 - **$1: StageName** {"dev" | "test" | "stg"}
 - **$2: ProjectName** "apd"
```
./script.sh {StageName} {ProjectName}
```

## **Step-by-step**
1. Generate KMS Key Pair
2. Create CloudFront PublicKey
3. Add Public Key to CloudFront Key Group
4. Create SSM Parameter
5. Create secret

## **Example**
```
./script.sh dev apd
```