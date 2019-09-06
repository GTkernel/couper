#!/bin/bash

# put customized data
INPUT_DIR="../"
MODEL_NAME="vgg"
STRONGMAN_FILE="${MODEL_NAME}_sm"
OUTPUT_DIR="gpu/${MODEL_NAME}/hybrid"
KUBECONF_FILE="${CONF_FILE}"
LAYER_NAME="BREAKPOINT"
K8S_MASTER_IP=""
USER_NAME=""
PRIVATE_SSH_KEY=""
LAYER_COUNT=0

call_remote () {
#$1 account
#$2 IP/hostname
#$3 key
#$4 command 
  if [[ $3 = "" ]]; then
    ssh $1@$2 -- $4 < /dev/null
  else
    ssh -i $3 $1@$2 -- $4 < /dev/null
  fi   
}

camera_parser () {

 call_remote $USER_NAME $K8S_MASTER_IP $PRIVATE_SSH_KEY "kubectl logs $1 $2 --tail 25" | {

  while IFS='' read -r line
  do
    if [[ $line = *"latency"* ]]; then
      if [[ $line = *"nne"* ]]; then
        NNE_TIME=$(echo $line | cut -d' ' -f4)
        echo $NNE_TIME >> $OUTPUT_DIR/camera_nne
      fi

      if [[ $line = *"sender"* ]]; then echo $line | cut -d' ' -f4 >> $OUTPUT_DIR/camera_network; fi
    fi

    if [[ $line = *"frame count"* ]]; then echo $line | cut -d' ' -f4 >> $OUTPUT_DIR/camera_frame; fi
    if [[ $line = *"last id"* ]]; then echo $line | cut -d' ' -f4 >> $OUTPUT_DIR/camera_ffid; fi

    echo $line >> $OUTPUT_DIR/${LAYER_COUNT}_log
  done

  }

}


remote_parser () {

 call_remote $USER_NAME $K8S_MASTER_IP $PRIVATE_SSH_KEY "kubectl logs $1 $2 --tail 25" | {
  
  while IFS='' read -r line
  do
    if [[ $line = *"latency"* ]]; then
      if [[ $line = *"nne"* ]]; then
        NNE_TIME=$(echo $line | cut -d' ' -f4)
        echo $NNE_TIME >> $OUTPUT_DIR/${2}
      fi

      if [[ $line = *"sender"* ]]; then
        echo $line | cut -d' ' -f4 >> $OUTPUT_DIR/${2}_network
      fi
    fi

    if [[ $line = *"frame count"* ]]; then echo $line | cut -d' ' -f4 >> $OUTPUT_DIR/${2}_frame; fi
    if [[ $line = *"last id"* ]]; then echo $line | cut -d' ' -f4 >> $OUTPUT_DIR/${2}_ffid; fi
    if [[ $line = *"drop rate"* ]]; then echo $line | cut -d' ' -f4 >> $OUTPUT_DIR/${2}_droprate; fi
    if [[ $line = *"data size"* ]]; then echo $line | cut -d' ' -f4 >> $OUTPUT_DIR/${2}_rcv_data; fi

    echo $line >> $OUTPUT_DIR/${LAYER_COUNT}_log
  done
  
  }

}


while IFS='' read -r NEW_LAYER_NAME || [[ -n "$NEW_LAYER_NAME" ]]; do
##### 
  #call remote machine to update
  call_remote $USER_NAME $K8S_MASTER_IP $PRIVATE_SSH_KEY "sed -i 's@'"$LAYER_NAME"'@'"$NEW_LAYER_NAME"'@g' $KUBECONF_FILE"

  echo $NEW_LAYER_NAME >> $OUTPUT_DIR/layers

  call_remote $USER_NAME $K8S_MASTER_IP $PRIVATE_SSH_KEY "kubectl create -f $KUBECONF_FILE"

  #wait for another 60 seconds
  sleep 180

  #if still not finished, wait for 5 seconds
  while [ "$(call_remote $USER_NAME $K8S_MASTER_IP $PRIVATE_SSH_KEY "kubectl get pod" | grep "split-nne-0" | awk '{print $3}')" != "Completed" ] || [ "$(call_remote $USER_NAME $K8S_MASTER_IP $PRIVATE_SSH_KEY "kubectl get pod" | grep "split-nne-1" | awk '{print $3}')" != "Completed" ] || [ "$(call_remote $USER_NAME $K8S_MASTER_IP $PRIVATE_SSH_KEY "kubectl get pod" | grep "split-nne-2" | awk '{print $3}')" != "Completed" ]
  do
    sleep 5
  done

  NNE0_NAME=$(call_remote $USER_NAME $K8S_MASTER_IP $PRIVATE_SSH_KEY "kubectl get pod -l app=split-nne" | awk '{print $1}' | grep "split-nne-0")
  NNE1_NAME=$(call_remote $USER_NAME $K8S_MASTER_IP $PRIVATE_SSH_KEY "kubectl get pod -l app=split-nne" | awk '{print $1}' | grep "split-nne-1")
  NNE2_NAME=$(call_remote $USER_NAME $K8S_MASTER_IP $PRIVATE_SSH_KEY "kubectl get pod -l app=split-nne" | awk '{print $1}' | grep "split-nne-2")
  camera_parser $NNE0_NAME camera
  remote_parser $NNE1_NAME nne1
  remote_parser $NNE2_NAME nne2
  

  $USER_NAME $K8S_MASTER_IP $PRIVATE_SSH_KEY "kubectl delete -f $KUBECONF_FILE"

  NNE1=$(tail -n 1 ${OUTPUT_DIR}/nne1)
  NNE2=$(tail -n 1 ${OUTPUT_DIR}/nne2)
# hybrid method mechanism
  if [[ $(./great_equal.py $NNE1 $NNE2) = 'True' ]]; then break; fi

  LAYER_NAME=$NEW_LAYER_NAME

  sleep 5

  (( LAYER_COUNT++ ))

  echo $LAYER_COUNT

done < "$INPUT_DIR/$STRONGMAN_FILE"
